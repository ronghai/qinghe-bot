
require 'time'
class String
  def titleize
    self.split(/ |\_/).map(&:capitalize).join(" ")
  end
end
module Lita
  module Handlers
    class TaskHandler < Handler
      RPREFIX = "dev"
      
      #
      route /^set group to (.*)$/, :group=, command:true
      route /^(add|remove) (.*) (from|to) team (.*)$/i, :team_member, command:true
      route /^team members$/i, :team_members, command:true

      #will check it later
      route /^set ([^']+)'s nickname to (.*)$/i, :nickname=, command:true
      route /^set ([^']+)'s team leader to (.*)$/i, :teamleader=, command:true
      
      route /^assign ["]?(.*)["]? to (.*)$/i, :assign_task, command:true
      route /^glist ([^']+)'s tasks$/i, :team_tasks, command:true
      route /^(clear|list) ([^']+)'s tasks$/i, :tasks, command:true
      
      
      
      #check
      route /^remove #(\d+) from ([^']+)([']s list)?/i, :remove_task, command:true
      
      #check
      route /^(add|remove) (.*) (from|to) (.*)[']s (to|cc|bcc) list$/i, :task_receiver, command:true
      #'      
      route /^prepare email$/i, :prepare_email, command:true
      #'
      #add/remove member from/to g1:team
      # dev:g1:team = []
      
      def team_member(res)
        matches =  res.matches[0]
        cmd =  matches[0].downcase.strip
        who =  matches[1] #.downcase
        g = matches[3].downcase.strip
        key = "#{RPREFIX}:#{g}:team"
        #puts key
        if cmd == 'add'
          redis.sadd(key, who)
        else
          redis.srem(key, who)
        end
        res.reply("#{who} has been #{cmd}ed #{matches[2]} #{g.upcase}")
      end

      
      def team_members(res)
        g = group(res)
        unless g
          return
        end
        key = "#{RPREFIX}:#{g}:team"
        #puts key
        #puts redis.smembers(key)
        m = redis.smembers(key).map(&:titleize).join("\n")
        if m.empty?
          res.reply("There no member in #{g}")
        else
          res.reply(m)
        end
      end

      # set member's nickname to ronghai
      # dev:member:nickname = {} // realname to nickname
      
      # dev:member:realname = {} // nickname to realname
      def nickname=(res)
        matches =  res.matches[0]
        realname =  matches[0]
        nickname =  matches[1].downcase
        key = "#{RPREFIX}:member:nickname"
        old = redis.hget(key, realname)
        redis.hset(key, realname, nickname)
        key = "#{RPREFIX}:member:realname"
        redis.hdel(key, old)
        redis.hset(key, nickname, realname)
        res.reply("#{realname}'s nickname is #{nickname}")
      end


      

      # set g1's team leader to ronghai
      # dev:g1:teamleader = ""
      
      def teamleader=(res)
        matches =  res.matches[0]
        member = real_member(res, matches[1])
        redis.set("#{RPREFIX}:#{matches[0].downcase}:teamleader", member)
        res.reply("#{matches[0]}'s leader is #{member}")
      end

      #assign .... to Limei
      #dev:g1:team:limei:tasks = []
      
      def assign_task(res)
        g = group(res)
        task = res.matches[0][0].strip
        member = real_member(res, res.matches[0][1].strip)
        #puts "member is #{member}"
        key = "#{RPREFIX}:#{g}:team:#{member_redis(member)}:tasks"
        redis.rpush(key, task)
        res.reply("#{member}\n#{list_tasks(key)}")
      end

      #list g1's task
      
      def team_tasks(res)
        g = res.matches[0][0].downcase
        members = redis.smembers("#{RPREFIX}:#{g}:team")
        #puts members
        #puts members.class
        all = members.map do |m|
          key = "#{RPREFIX}:#{g}:team:#{member_redis(m)}:tasks"
          tasks = list_tasks(key)
          "#{m.capitalize}\n#{tasks}\n"
        end
        all = all.join("\n")
        res.reply(all)
      end

      #clear Limei's task
      #list limei's taks
      
      def tasks(res)
        g = group(res)
        matches =  res.matches[0]
        cmd = matches[0].downcase
        member = real_member(res, matches[1])
        key = "#{RPREFIX}:#{g}:team:#{member_redis(member)}:tasks"
        if cmd == 'clear'
          redis.del(key)
          res.reply("all tasks have been removed")
        else
          task = list_tasks(key)
          if task.empty?
            res.reply("#{member} has no task")
          else
            res.reply("#{member}'s tasks \n #{task}")
          end
        end
      end

      #remove #2 from limei
      
      def remove_task(res)
        matches =  res.matches[0]
        ti = matches[0].to_i - 1
        member = real_member(res, matches[1])
        g = group(res)
        key = "#{RPREFIX}:#{g}:team:#{member_redis(member)}:tasks"
        task = redis.lrange(key, ti, ti)
        redis.lrem(key, 1, task)
        res.reply("#{task[0]} has been removed from #{member}'s list\n"+
            "Now#{member}is working on the following\n#{list_tasks(key)}")
      end


      def list_tasks(key)
        list = redis.lrange(key, 0, -1)
        unless list
          return []
        end
        list.map.with_index { |x, i| "\##{i+1} #{x}" }.join("\n")
        #tasks = ""
        #list.each_index {|x| task << "\##{x} #{list[x]}\n" }
        #tasks
      end
      
      def member_redis(member)
        member.split.join.downcase
      end

      def real_member(res, nickname)
        real =redis.hget("#{RPREFIX}:member:realname", nickname)
        #puts "#{nickname}'s real name is #{real}"
        real.nil? ? nickname : real.capitalize
      end

      #add/remove email from/to g1:task's to/cc/bcc list
      # dev:g1:task:receiver:[to|cc|bcc]
      #
      #(add|remove) (.*) (from|to) (.*)[']s (to|cc|bcc) list$/
      def task_receiver(res)
        matches =  res.matches[0]
        cmd =  matches[0].downcase
        email =  matches[1] #.downcase
        part = group(res, matches[3].downcase)
        unless part
          return
        end
        rct =  matches[4].downcase
        key = "#{RPREFIX}:#{part}:receiver:#{rct}"
        if cmd == 'add'
          redis.sadd(key, email)
        else
          redis.srem(key, email)
        end      
        res.reply("#{email} has been #{cmd}ed #{matches[2]} #{part}'s #{rct} list")
      end


      # dev:user.id:group = ""
        
      def group=(res)
        redis.set("#{RPREFIX}:#{res.user.id}:group", res.matches[0][0].downcase)
        res.reply("Your group is #{res.matches[0][0]} now.")
      end

      def group(res, part=nil)
        if !part.nil? && part.include?(":")
          part
        else
          group = redis.get("#{RPREFIX}:#{res.user.id}:group")
          unless group
            res.reply("Team is G1. You can use 'set group to `group`' to update team'")
            group = 'G1'.downcase
          end
          part.nil? ? group : group+":"+part
        end
      end

      #prepare email
      
      def prepare_email(res)
        g = group(res)
        subject = "#{g.upcase} Tasks " + (Time.now +  (60 * 60 * 24)).strftime("%Y%m%d")
        res.reply(subject)
      end
      Lita.register_handler(self)
    end
  end
end

