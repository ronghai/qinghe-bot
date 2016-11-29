
require 'time'
module Lita
  class TaskHandler < Handler
    RPREFIX = "dev"
    #add/remove email from/to g1:task's to/cc/bcc list
    # dev:g1:task:receiver:[to|cc|bcc]
    route /^(add|remove) (.*) (from|to) (.*)['']s (to|cc|bcc) list$/i, :task_mail_address, command:true
  
    # dev:user.id:group = ""
    route /^set group to (.*)$/, :group=, command:true  

    #add/remove member from/to g1:team
    # dev:g1:team = []
    route /^(add|remove) (.*) (from|to) team$/i, :team_member, command:true
    def team_member(res)
      matches =  res.matches[0]
      cmd =  matches[0].downcase.trim
      who =  matches[1] #.downcase
      g = group(res)
      unless g
        return
      end
      key = "#{RPREFIX}:#{g}:team"
      if cmd == 'add'
        redis.sadd(key, who.downcase)
      else
        redis.srem(key, who.downcase)
      end
      res.reply("#{who} has been #{cmd}ed #{matches[2]} #{g}")
    end

    route /^list team members$/i, :list_team_members, command:true
    def list_team_members(res)
      g = group(res)
      unless g
        return
      end
      key = "#{RPREFIX}:#{g}:team"
      m = redis.smembers(key).join("\n")
      res.reply m
    end

    # set member's nickname to ronghai
    # dev:member:nickname = {} // realname to nickname
    route /^set (.*)''s nickname to (.*)$/i, :nickname=, command:true
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
    end

    # set g1's team leader to ronghai
    # dev:g1:teamleader = ""
    route /^set ([^'']+)''s team leader to (.*)$/i, :teamleader=, command:true
    def teamleader=(res)
      matches =  res.matches[0]
      member = real_member(res, matches[1])
      redis.set("#{RPREFIX}:#{matches[0].downcase}:teamleader", member)
      res.reply("#{matches[0]}'s leader is #{member}")
    end

    #add .... to Limei
    #dev:g1:team:limei:tasks = []
    route /^add (.*) to (.*)$/, :add_task, command:true
    def add_task(res)
      g = group(res)
      unless g
        return
      end
      task = res.matches[0][0]
      member = real_member(res.matches[0][1])
      key = "#{RPREFIX}:#{g}:team:#{member_redis(member)}:tasks"
      redis.rpush(key, task)
      res.reply("#{member}\n#{list_tasks(key)}")
    end

    #list g1's task
    route /^list ([^'']+)''s task/i, :list_all_tasks, command:true
    def list_all_tasks
      g = res.matches[0][0].downcase
      members = redis.lrange("#{RPREFIX}:#{g}:team", 0, -1)
      all = members.map do |m|
        key = "#{RPREFIX}:#{g}:team:#{member_redis(m)}:tasks"
        tasks = list_tasks(key)
        "#{m}\n#{tasks}"
      end.join("\n")
      res.reply(all)
    end

    #clear Limei's task
    #list limei's taks
    route /^(clear|list) ([^']+)([']s(.*))?$/i, :qm_tasks, command:true
    def qm_tasks(res)
      g = group(res)
      unless g
        return
      end
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
    route /^remove #(\d+) from ([^']+)([']s list)?/i, :remove_task, command:true
    def remove_task(res)
      matches =  res.matches[0]
      ti = matches[0].to_i
      member = real_member(res, matches[1])
      g = group(res)
      unless g
        return
      end
      key = "#{RPREFIX}:#{g}:team:#{member_redis(member)}:tasks"
      task = redis.lrange(key, ti, ti)
      redis.lrem(key, 1, task)
      res.reply("#{task} has been removed from #{member}'s list \n#{list_tasks(key)}")
    end


    def list_tasks(key)
      list = redis.lrange(key, 0, -1)
      unless list
        return []
      end
      list.map.with_index { |x, i| "\##{i} #{x}" }.join("\n")
      #tasks = ""
      #list.each_index {|x| task << "\##{x} #{list[x]}\n" }
      #tasks
    end
    
    def member_redis(member)
      member.split.join.downcase
    end

    def real_member(res, nickname)
      real =redis.hget("#{RPREFIX}:member:realname", nickname)
      if real
        real        
      end
      nickname
    end

    
    def task_mail_address(res)
      matches =  res.matches[0]
      cmd =  matches[0].downcase
      email =  matches[1] #.downcase
      part = group(matches[3].downcase, part)
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



    def group=(res)
      redis.set("#{RPREFIX}:#{res.user.id}:group", res.matches[0][0])
      res.reply("Your group is #{res.matches[0][0]} now.")
    end

    def group(res, part=nil)
      if !part.nil? && part.include?(":")
        part
      else
        group = redis.get("#{RPREFIX}:#{res.user.id}:group")
        unless group
          res.reply("please use 'set group to `group` to update group first'")
          return nil
        end
        part.nil? ? group : group+":"+part
      end
    end

    #prepare email
    route /^prepare email$/i, :prepare_email, command:true
    def prepare_email(res)
      g = group(res)
      unless g
        return
      end
      subject = "#{g.upcase} Tasks " + (Time.now +  (60 * 60 * 24)).strftime("%Y%m%d")

    end

  end
  Lita.register_handler(TaskHandler)
end

