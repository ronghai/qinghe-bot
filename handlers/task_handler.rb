
require 'time'
module Lita
  module Handlers
    class TaskHandler < Handler
      RPREFIX = "dev"
      #add/remove email from/to g1:task's to/cc/bcc list
      # dev:g1:task:receiver:[to|cc|bcc]
      #route /^(add|remove) (.*) (from|to) (.*)['']s (to|cc|bcc) list$/i, :task_mail_address, command:true
    
      # dev:user.id:group = ""
      route /^set group to (.*)$/, :group=, command:true  

      



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
        res.reply(subject)
      end
      Lita.register_handler(self)
    end
  end
end

