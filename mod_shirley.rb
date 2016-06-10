module Shirley

  require "net/http"
  require "uri"
  require "json"
  require "net/https"

  class Slackpush
    def initialize slackhook
      @slackhook = slackhook
      @slackuname = "admin"
      @cores = `grep 'model name' /proc/cpuinfo | wc -l`
      @hostname = `hostname`
    end
    def worker
      payload = get_payload
      begin
      `curl -X POST --data-urlencode 'payload=#{payload}' #{@slackhook}`
      `echo #{payload} >> slackmonit.log`
      rescue
        p "Error pushing to slack"
      end
    end
    def get_payload
      raise NotImplementedError, "get_payload method not implemented in #{self.class}"
    end
  end

  class Observer < Slackpush
    ###
    # 5 cycles or immediate ?
    ###
    # Agent Unreachable
    # Load Average >0.7, critical if >1
    # CPU Usage
    # Memory usage
    ###
    # run this every minute
    # configure thresholds
    # if a threashold is broken, send the payload
    # but carry on checking all the rest of it
    def get_payload
      data = {:text => "Hey, @#{@slackuname}!\n*ALERT*\nHost: #{@hostname}\n#{@@actual_payload}" }
      payload = data.to_json
      `curl -X POST --data-urlencode 'payload=#{payload}' #{@slackhook}`
      `echo #{payload} >> slackmonit.log`
      return 0
    end
    def periodiccheck
      # 0.7, 1.0
      loadavg_min = `cat /proc/loadavg | awk '{ print $1 }'` # 1 5 15
      weird = ( (loadavg_min.to_f + 1) * 100).to_i
      p "#{loadavg_min}, #{loadavg_min.to_f}, #{weird}, #{weird.class}"
      if loadavg_min.to_f > 170
        @@actual_payload="1 minute load average\n#{loadavg_min} (cores: #{@cores})"
        self.get_payload
      elsif loadavg_min.to_f > 200
        @@actual_payload="CRITICAL! 1 minute load average\n#{loadavg_min}  (cores: #{@cores})"
        self.get_payload
      end
      # 100
      uptime = `uptime | grep -ohe 'up .*' | sed 's/,//g' | awk '{ print $2" "$3 }'`
      if uptime.to_i > 100
        @@actual_payload="Server up too long: \n#{uptime.to_i} days"
        self.get_payload
      end
      # 5
      #disk = `df -h --total | awk  ' /total/ { print "total\" : \""$2"\", \"used\" : \""$3"\", \"free\" : \""$4"\", \"percentage\" : \""$5" " }'`
      diskfree = `df -h --total | awk  ' /total/ { print $4 }' | grep -o '[0-9]*'`
      if diskfree.to_i < 5
        @@actual_payload="HDD getting full: \n#{diskfree.to_i}G remaining"
        self.get_payload
      end
      # <10 free
      totmem = `free -m |  awk '/Mem/ {printf $4 }'`
      freemem = `free -m |  awk '/Mem/ {printf $4 }'`
      if freemem.to_i < 10
        @@actual_payload="Running out of RAM: \n#{freemem.to_i}M remaining, total - #{totmem.to_i}"
        self.get_payload
      end
      # < 50 free swap
      freeswap = `free -m |  awk '/Swap/ {printf $4 }'`
      if freeswap.to_i < 10
        @@actual_payload="Running out of swap: \n#{freeswap.to_i}M remaining"
        self.get_payload
      end
    end
  end

  class ApacheCentos7 < Slackpush
    def get_payload
      content = self.simplecheck
      data = {:text => content }
      payload = data.to_json
      return payload
    end
    def simplecheck
      content = "*Apache CentOS 7 simplecheck*\n\n_Server time: #{Time.now}_\n\nHost: #{@hostname}\n\nHey, @#{@slackuname}!\n\n"
       lavs = `cat /proc/loadavg`
      content += "Load averages: #{lavs}\n"
       syncookies = `netstat -s | grep 'invalid SYN cookies' | grep -o '[0-9]*'`
        syncookies.chomp!
      content += "\nInvalid syn cookies: #{syncookies.to_i}\n" # make a comparison
       procs = `ps aux | sort -nk +4 | tail `
      content += "\nProcesses:\n```#{procs}```\n"
       freemem = `sudo free -ht`
      content += "\n```#{freemem}```\n"
       zombies = `ps aux | grep 'Z'`
      content += "Zombie processes:\n```#{zombies}```\n"
       memusage = `sudo ps -ylC httpd | awk '{x += $8;y += 1} END {print "Apache Memory Usage (MB): "x/1024; print "Average Process Size (MB): "x/((y-1)*1024)}'`
      content += "\n#{memusage}\n"
      content += "_And now something completely different!_\n\n"
       workers = `sudo cat /var/log/httpd/ssl_error_log | grep 'MaxRequestWorkers'`
      content += " - MaxRequestWorkers complaints, if any - \n#{workers}\n"
       servers = `sudo cat /var/log/httpd/ssl_error_log | grep 'StartServers'`
      content += " - MinMaxServers complaints, if any - \n#{servers}\n"
       cookie = Shirley::Fortune.new.do
      content += "\n\n\n\n\n*#{cookie}*"
    return content
    end
  end#class

  class ApacheUbuntu1404 < Slackpush
    def get_payload

      # this needs monitor and worker
      content = self.simplecheck

      data = {:text => content }
      payload = data.to_json
      return payload
    end
    def simplecheck
      content = "*Apache Ubuntu 14 04 simplecheck*\n_Server time: #{Time.now}_"
       syncookies = `netstat -s | grep 'invalid SYN cookies' | grep -o '[0-9]*'`
        syncookies.chomp!
      content += "\nInvalid syn cookies: #{syncookies.to_i}\n" # make a comparison
       procs = `ps aux | sort -nk +4 | tail `
      content += "\nProcesses:\n```#{procs}```\n"
       memusage = `sudo ps -ylC apache2 | awk '{x += $8;y += 1} END {print "Apache Memory Usage (MB): "x/1024; print "Average Process Size (MB): "x/((y-1)*1024)}'`
      content += "\n#{memusage}\n"
       freemem = `sudo free -ht`
      content += "\n```#{freemem}```\n"
       zombies = `ps aux | grep 'Z'`
      content += "Zombie processes:\n```#{zombies}```\n"
      # mpm_prefork
       workers = `sudo cat /var/log/apache2/error.log | grep 'MaxRequestWorkers'`
      content += "_And now something completely different!_\n\nMaxRequestWorkers complaints:\n```#{workers}```\n"
       servers = `sudo cat /var/log/apache2/error.log | grep 'StartServers'`
      content += "MinMaxServers complaints:\n```#{servers}```\n"
       xmlrpc = `sudo cat /var/log/apache2/access.log | grep 'xmlrpc' | grep '200'`
      content += "Accepted XMLRPC requests:\n```#{xmlrpc}```\n"
       cookie = Shirley::Fortune.new.do
      content += "\n\n\n\n\n*#{cookie}*"
    return content
    end
  end#class


  class Fortune
   attr_accessor :cookies
   def parser( cookies )
    cookie = cookies.sample
    return cookie
   end
   def do
    cookies = ["â€œWelcomeâ€ is a powerful word.",
      "A dubious friend may be an enemy in camouflage.",
      "A feather in the hand is better than a bird in the air. (2)",
      "A fresh start will put you on your way.",
      "A friend asks only for your time not your money.",
      "A friend is a present you give yourself.",
      "A gambler not only will lose what he has, but also will lose what he doesnâ€™t have.",
      "A golden egg of opportunity falls into your lap this month.",
      "A good time to finish up old tasks. (2)",
      "A hunch is creativity trying to tell you something.",
      "A light heart carries you through all the hard times.",
      "A new perspective will come with the new year. (2)",
      "A person is never to (sic) old to learn. (2)",
      "A person of words and not deeds is like a garden full of weeds.",
      "A pleasant surprise is waiting for you.",
      "A smile is your personal welcome mat.",
      "A smooth long journey! Great expectations.",
      "A soft voice may be awfully persuasive.",
      "A truly rich life contains love and art in abundance.",
      "Accept something that you cannot change, and you will feel better.",
      "Adventure can be real happiness.",
      "Advice is like kissing. It costs nothing and is a pleasant thing to do.",
      "Advice, when most needed, is least heeded.",
      "All the effort you are making will ultimately pay off.",
      "All the troubles you have will pass away very quickly.",
      "All will go well with your new project.",
      "All your hard work will soon pay off.",
      "Allow compassion to guide your decisions.",
      "An agreeable romance might begin to take on the appearance.",
      "An important person will offer you support.",
      "An inch of time is an inch of gold.",
      "Be careful or you could fall for some tricks today.",
      "Beauty in its various forms appeals to you. (2)",
      "Because you demand more from yourself, others respect you deeply.",
      "Believe in yourself and others will too.",
      "Believe it can be done.",
      "Better ask twice than lose yourself once.",
      "Carve your name on your heart and not on marble.",
      "Change is happening in your life, so go with the flow!",
      "Competence like yours is underrated.",
      "Congratulations! You are on your way.",
      "Could I get some directions to your heart? (2)",
      "Courtesy begins in the home.",
      "Courtesy is contagious.",
      "Curiosity kills boredom. Nothing can kill curiosity.",
      "Dedicate yourself with a calm mind to the task at hand.",
      "Depart not from the path which fate has you assigned.",
      "Determination is what you need now.",
      "Disbelief destroys the magic.",
      "Distance yourself from the vain.",
      "Do not be intimidated by the eloquence of others.",
      "Do not let ambitions overshadow small success.",
      "Do not make extra work for yourself.",
      "Do not underestimate yourself. Human beings have unlimited potentials.",
      "Donâ€™t be discouraged, because every wrong attempt discarded is another step forward.",
      "Donâ€™t confuse recklessness with confidence. (2)",
      "Donâ€™t just spend time. Invest it.",
      "Donâ€™t just think, act!",
      "Donâ€™t let friends impose on you, work calmly and silently.",
      "Donâ€™t let the past and useless detail choke your existence.",
      "Donâ€™t let your limitations overshadow your talents.",
      "Donâ€™t worry; prosperity will knock on your door soon.",
      "Each day, compel yourself to do something you would rather not do.",
      "Education is the ability to meet lifeâ€™s situations.",
      "Emulate what you admire in your parents. (2)",
      "Emulate what you respect in your friends.",
      "Every flower blooms in its own sweet time.",
      "Every wise man started out by asking many questions.",
      "Everyday in your life is a special occasion.",
      "Failure is the chance to do better next time.",
      "Feeding a cow with roses does not get extra appreciation.",
      "For hate is never conquered by hate. Hate is conquered by love.",
      "Fortune Not Found: Abort, Retry, Ignore?",
      "From listening comes wisdom and from speaking repentance.",
      "From now on your kindness will lead you to success.",
      "Get your mind set â€” confidence will lead you on.",
      "Get your mind setâ€¦confidence will lead you on.",
      "Go take a rest; you deserve it.",
      "Good news will be brought to you by mail.",
      "Good news will come to you by mail.",
      "Good to begin well, better to end well.",
      "Happiness begins with facing life with a smile and a wink.",
      "Happiness will bring you good luck.",
      "Happy life is just in front of you.",
      "Hard words break no bones, fine words butter no parsnips.",
      "Have a beautiful day.",
      "He who expects no gratitude shall never be disappointed. (2)",
      "He who knows he has enough is rich.",
      "Help! Iâ€™m being held prisoner in a chinese bakery!",
      "How you look depends on where you go.",
      "I learn by going where I have to go.",
      "If a true sense of value is to be yours it must come through service.",
      "If certainty were truth, we would never be wrong.",
      "If you continually give, you will continually have.",
      "If you look in the right places, you can find some good offerings.",
      "If you think you can do a thing or think you canâ€™t do a thing, youâ€™re right.",
      "If your desires are not extravagant, they will be granted.",
      "If your desires are not to extravagant they will be granted. (2)",
      "In order to take, one must first give.",
      "In the end all things will be known.",
      "It could be better, but its[sic] good enough.",
      "It is better to deal with problems before they arise.",
      "It is honorable to stand up for what is right, however unpopular it seems.",
      "It is worth reviewing some old lessons.",
      "It takes courage to admit fault.",
      "Itâ€™s time to get moving. Your spirits will lift accordingly.",
      "Keep your face to the sunshine and you will never see shadows.",
      "Let the world be filled with tranquility and goodwill.",
      "Listen not to vain words of empty tongue.",
      "Listen to everyone. Ideas come from everywhere.",
      "Living with a commitment to excellence shall take you far.",
      "Long life is in store for you.",
      "Love is a warm fire to keep the soul warm.",
      "Love is like sweet medicine, good to the last drop.",
      "Love lights up the world.",
      "Love truth, but pardon error. (2)",
      "Man is born to live and not prepared to live.",
      "Many will travel to hear you speak.",
      "Meditation with an old enemy is advised.",
      "Miles are covered one step at a time.",
      "Nature, time and patience are the three great physicians.",
      "Never fear! The end of something marks the start of something new.",
      "New ideas could be profitable.",
      "New people will bring you new realizations, especially about big issues. (2)",
      "No one can walk backwards into the future.",
      "Now is a good time to buy stock.",
      "Now is the time to go ahead and pursue that love interest!",
      "Now is the time to try something new",
      "Now is the time to try something new.",
      "Others can help you now.",
      "Pennies from heaven find their way to your doorstep this year!",
      "People are attracted by your Delicate[sic] features.",
      "People find it difficult to resist your persuasive manner.",
      "Perhaps youâ€™ve been focusing too much on saving.",
      "Physical activity will dramatically improve your outlook today.",
      "Place special emphasis on old friendship.",
      "Please visit us at www.wontonfood.com",
      "Practice makes perfect.",
      "Protective measures will prevent costly disasters.",
      "Put your mind into planning today. Look into the future.",
      "Remember to share good fortune as well as bad with your friends.",
      "Rest has a peaceful effect on your physical and emotional health.",
      "Resting well is as important as working hard.",
      "Romance moves you in a new direction.",
      "Savor your freedom â€” it is precious.",
      "Say hello to others. You will have a happier day.",
      "Self-knowledge is a life long process.",
      "Share your joys and sorrows with your family.",
      "Sloth makes all things difficult; industry all easy.",
      "Small confidences mark the onset of a friendship.",
      "Society prepares the crime; the criminal commits it.",
      "Someone you care about seeks reconciliation.",
      "Soon life will become more interesting.",
      "Stand tall. Donâ€™t look down upon yourself. (2)",
      "Stop searching forever, happiness is just next to you.",
      "Success is a journey, not a destination.",
      "Success is going from failure to failure without loss of enthusiasm.",
      "Take care and sensitivity you show towards others will return to you.",
      "Take the high road.",
      "The austerity you see around you covers the richness of life like a veil.",
      "The best prediction of future is the past.",
      "The change you started already have far-reaching effects. Be ready.",
      "The change you started already have far-reaching effects. Be ready.",
      "The first man gets the oyster, the second man gets the shell.",
      "The harder you work, the luckier you get.",
      "The night life is for you.",
      "The one that recognizes the illusion does not act as if it is real.",
      "The only people who never fail are those who never try.",
      "The person who will not stand for something will fall for anything.",
      "The philosophy of one century is the common sense of the next.",
      "The saints are the sinners who keep on trying.",
      "The secret to good friends is no secret to you. (2)",
      "The small courtesies sweeten life, the greater ennoble it.",
      "The smart thing to do is to begin trusting your intuitions.",
      "The strong person understands how to withstand substantial loss.",
      "The sure way to predict the future is to invent it.",
      "The truly generous share, even with the undeserving.",
      "The value lies not within any particular thing, but in the desire placed on that thing.",
      "The weather is wonderful. (2)",
      "There is no mistake so great as that of being always right.",
      "There is no wisdom greater than kindness. (2)",
      "There is not greater pleasure than seeing your lived (sic) ones prosper.",
      "Thereâ€™s no such thing as an ordinary cat.",
      "Things donâ€™t just happen; they happen just.",
      "Those who care will make the effort.",
      "Time and patience are called for many surprises await you!. (sic)",
      "Time is precious, but truth is more precious than time",
      "To know oneself, one should assert oneself.",
      "Today is the conserve yourself, as things just wonâ€™t budge.",
      "Today, your mouth might be moving but no one is listening.",
      "Tonight you will be blinded by passion.",
      "Use your eloquence where it will do the most good.",
      "Welcome change.",
      "Well done is better than well said.",
      "Whatâ€™s hidden in an empty box?",
      "Whatâ€™s yours in mine, and whatâ€™s mine is mine.",
      "When your heart is pure, your mind is clear.",
      "Wish you happiness.",
      "You always bring others happiness.",
      "You are a person of another time.",
      "You are a talented storyteller. (2)",
      "You are admired by everyone for your talent and ability.",
      "You are almost there.",
      "You are busy, but you are happy.",
      "You are generous to an extreme and always think of the other fellow.",
      "You are going to have some new clothes. (2)",
      "You are in good hands this evening.",
      "You are modest and courteous.",
      "You are never selfish with your advice or your help.",
      "You are next in line for promotion in your firm.",
      "You are offered the dream of a lifetime. Say yes!",
      "You are open-minded and quick to make new friends. (2)",
      "You are solid and dependable.",
      "You are soon going to change your present line of work.",
      "You are talented in many ways.",
      "You are the master of every situation. (2)",
      "You are very expressive and positive in words, act and feeling.",
      "You are working hard.",
      "You begin to appreciate how important it is to share your personal beliefs.",
      "You desire recognition and you will find it.",
      "You have a deep appreciation of the arts and music.",
      "You have a deep interest in all that is artistic.",
      "You have a friendly heart and are well admired. (2)",
      "You have a shrewd knack for spotting insincerity.",
      "You have a yearning for perfection. (3)",
      "You have an active mind and a keen imagination.",
      "You have an ambitious nature and may make a name for yourself.",
      "You have an unusual equipment for success, use it properly.",
      "You have exceeded what was expected.",
      "You have the power to write your own fortune.",
      "You have yearning for perfection.",
      "You know where you are going and how to get there.",
      "You look pretty.",
      "You love challenge.",
      "You love chinese food.",
      "You make people realize that there exist other beauties in the world.",
      "You never hesitate to tackle the most difficult problems. (2)",
      "You seek to shield those you love and like the role of provider. (2)",
      "You should be able to make money and hold on to it.",
      "You should be able to undertake and complete anything.",
      "You understand how to have fun with others and to enjoy your solitude.",
      "You will always be surrounded by true friends.",
      "You will always get what you want through your charm and personality.",
      "You will always have good luck in your personal affairs.",
      "You will be a great success both in the business world and society. (2)",
      "You will be blessed with longevity.",
      "You will be successful in your work.",
      "You will be traveling and coming into a fortune.",
      "You will be unusually successful in business.",
      "You will become a great philanthropist in your later years.",
      "You will become more and more wealthy.",
      "You will enjoy good health.",
      "You will enjoy good health; you will be surrounded by luxury.",
      "You will find great contentment in the daily, routine activities.",
      "You will have a fine capacity for the enjoyment of life.",
      "You will have gold pieces by the bushel.",
      "You will inherit a large sum of money.",
      "You will make change for the better.",
      "You will soon be surrounded by good friends and laughter.",
      "You will take a chance in something in near future.",
      "You will travel far and wide, both pleasure and business.",
      "You will travel far and wide,both pleasure and business.",
      "Your abilities are unparalleled.",
      "Your ability is appreciated.",
      "Your ability to juggle many tasks will take you far.",
      "Your biggest virtue is your modesty.",
      "Your character can be described as natural and unrestrained.",
      "Your difficulties will strengthen you.",
      "Your dreams are never silly; depend on them to guide you.",
      "Your dreams are worth your best efforts to achieve them.",
      "Your energy returns and you get things done.",
      "Your family is young, gifted and attractive.",
      "Your first love has never forgotten you.",
      "Your happiness is before you, not behind you! Cherish it.",
      "Your hard work will payoff today.",
      "Your heart will always make itself known through your words.",
      "Your home is the center of great love.",
      "Your ideals are well within your reach.",
      "Your infinite capacity for patience will be rewarded sooner or later.",
      "Your leadership qualities will be tested and proven.",
      "Your life will be happy and peaceful.",
      "Your life will get more and more exciting.",
      "Your love life will be happy and harmonious.",
      "Your love of music will be an important part of your life.",
      "Your loyalty is a virtue, but not when itâ€™s wedded with blind stubbornness.",
      "Your mind is creative, original and alert.",
      "Your mind is your greatest asset.",
      "Your quick wits will get you out of a tough situation.",
      "Your success will astonish everyone. (2)",
      "Your talents will be recognized and suitably rewarded.",
      "Your work interests can capture the highest status or prestige."]
      cookie = self.parser( cookies )
      cookie = cookie.to_s
      return cookie
   end
  end

end
