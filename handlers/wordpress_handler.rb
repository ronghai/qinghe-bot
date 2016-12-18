require 'time'
class String
  def titleize
    self.split(/ |:|\_/).map(&:capitalize).join(" ")
  end
end
module Lita
  module Handlers
    class WordpressHandler < Handler
      RPREFIX = "wordpress"
      META = [:post, :name, :title, :url, :image, :date, :excerpt];

      route /^post[:] (.*)/, :post, command:true


      def post(res)
        po = res.message.body.split("\n")
        meta = {}
        META.each_index do |index|
          key = "#{META[index].to_s}: "
          meta[META[index]] = po[index][(key.size)..-1]
        end
        #puts meta[:url]
        log.info "#{meta[:name]} #{meta[:url]}"
        content = po[8..-1].join("\n")
        res.reply("#{meta[:name]} #{url}")
      end




      Lita.register_handler(self)
  	end
  end
end