require "monitor"

class Dispatcher
end

class Worker
  def initialize id, lock, ergebnis#, currentthreadcount
    @id = id
    @lock = lock
    @ergebnis = ergebnis
#    @currentthreadcount = currentthreadcount
    #    @currentthreadcount += 1
    print "ich bin ein neuer thread mit task #{id}\n"
  end

  def machwas
    sleep 3 if @id.odd?
    sleep 1 if @id.even?

    aufgabe = @id * -1

    @lock.synchronize {
      #      5.times do
      #        print @id
      #        sleep rand #0.1
      #        # Thread.pass
      #      end

      puts "task #{@id} fertig"
      @ergebnis << aufgabe
 #     @currentthreadcount -= 1
    }
#    Thread.exit
    #self.kill
    
  end
end

lock = Monitor.new
threads = []
maxthreads = 2
#currentthreadcount = 0
puts "ich selbst bin thread:" + Thread.list.inspect

tasks = []
5.downto(1) {|x| tasks << x}
puts "tasks: " + tasks.inspect

ergebnis = []

while !tasks.empty?
  if (Thread.list.size - 1 < maxthreads)
    # neuen thread starten
    puts "starte neuen thread, gibt ja gerade nur #{Thread.list.size - 1} threads"
#    currentthreadcount += 1
    dertask = tasks.pop
    threads << Thread.new(dertask) { |arg|
      w = Worker.new arg, lock, ergebnis#, currentthreadcount
      w.machwas
    }

  else
    # keinen neuen thread starten
    puts "gerade kein slot frei, sondern #{Thread.list.size - 1} slots belegt"
    puts Thread.list.inspect
#    puts currentthreadcount if Thread.list.size == 1
    #Thread.pass
    puts ergebnis.inspect
    sleep 1
  end
end

puts "keine tasks mehr übrig, warte auf das fertigstellen"

threads.each {|t| t.join}
puts ergebnis.inspect
puts "fertig"