#!/usr/bin/env ruby

# file: cron_format.rb

require 'date'
require 'time'


MINUTE = 60
HOUR = MINUTE * 60
DAY = HOUR * 24
TF = "%s-%s-%s %s:%s"


class Array

  def inflate()
    Array.new(self.max_by {|x| x.length}.length).map do |x|
      self.map{|x| x.length <= 1 ? x.first : x.shift}
    end
  end
end


class CronFormat

  attr_reader :to_time, :to_expression

  def initialize(cron_string, now=Time.now)  
    @cron_string, @to_time = cron_string, now
    parse()
  end
  
  def next()
    nudge() unless @cron_string =~ %r{/}
    parse()
  end
  
  private    
  
  def nudge()

    a  =  @cron_string.split
    val = a.detect{|x| x != '*'}
    index, n = 0, 1

    if val then
      index = a.index(val)
      r = val[/\/(\d+)$/,1]     
      n = r.to_i if r
    end

    month_proc = lambda {|t1,n|
      a = t1.to_a
      a[4] = a[4] + n <= 12 ? a[4] + n  : a[4] + n - 12
      t = Time.parse(TF % a.values_at(5,4,3,2,1,0))
      t -= DAY until t.month == a[4]
      return t
    }

    day_proc = lambda {|x,n| x + n * DAY}

    units = [
      lambda {|x,n| x + n * MINUTE}, 
      lambda {|x,n| x + n * HOUR}, 
      day_proc, 
      month_proc,
      day_proc
    ]

    @to_time = units[index].call @to_time, n

  end    
  
  def parse()
    
    raw_a = @cron_string.split
    raw_a << '*' if raw_a.length <= 5 # add the year?

    units = @to_time.to_a.values_at(1..4) + [nil, @to_time.year]
      
    procs = {
        min: lambda {|x, interval| x += (interval * MINUTE).to_i},
       hour: lambda {|x, interval| x += (interval * HOUR).to_i},
        day: lambda {|x, interval| x += (interval * DAY).to_i}, 
      month: lambda {|x, interval| 
         date = x.to_a.values_at(1..5)
         interval.times { date[3].succ! }
         Time.parse(TF % date.reverse)},
       year: lambda {|x, interval| 
         date = x.to_a.values_at(1..5)
         interval.times { date[4].succ! }
         Time.parse(TF % date.reverse)}
    }

    dt = units.map do |start|
      # convert * to time unit
      lambda do |x| v2 = x.sub('*', start.to_s)
        # split any times
        multiples = v2.split(/,/)
        range = multiples.map do |time|
          s1, s2 = time.split(/-/)
          s2 ? (s1..s2).to_a : s1
        end
        range.flatten
      end

    end
    
    # take any repeater out of the unit value
    raw_units, repeaters = [], []

    raw_a.each do |x| 
      v1, v2 = x.split('/')
      raw_units << v1
      repeaters << v2
    end
    
    r = /(sun|mon|tues|wed|thurs|fri|satur|sun)(day)?|tue|thu|sat/i
    raw_units[4].gsub!(r) do |x|
      a = %w(sunday monday tuesday wednesday thursday friday saturday)
      a.index a.grep(/#{x}/i).first
    end
    
    @to_expression = (raw_a[0..3] + [raw_units[4]])[0..4].join ' '
    
    raw_date = raw_units.map.with_index {|x,i| dt[i].call(x) }
    
    # expand the repeater

    ceil = {min: MINUTE, hour: 23, day: 31, month: 12}.values

    if repeaters.any? then
      repeaters.each_with_index do |x,i|
        if x and not raw_a[i][/^\*/] then
          raw_date[i] = raw_date[i].map {|y|            
            (y.to_i...ceil[i]).step(x.to_i).to_a.map(&:to_s)
          }.flatten
        else  
          raw_date[i]
        end 
      end
    end  
   
    
    dates = raw_date.inflate
    
    a = dates.map do |date|

      d = date.map{|x| x ? x.clone : nil}
      wday, year = d.pop(2)
      
      d << year

      next unless day_valid? d.reverse.take 3
      t = Time.parse(TF % d.reverse)
        
      if t < @to_time and wday and wday != t.wday then
        d[2], d[3] = @to_time.to_a.values_at(3,4).map(&:to_s)
        t = Time.parse(TF % d.reverse)
        t += DAY until t.wday == wday.to_i
      end

      i = 3
      while t < @to_time and i >= 0 and raw_a[i][/\*/]

        d[i] = @to_time.to_a[i+1].to_s
        t = Time.parse(TF % d.reverse)
        i -= 1
      end

      if t < @to_time then

        if t.month < @to_time.month and raw_a[4] == '*' then
          # increment the year

          d[4].succ!
          t = Time.parse(TF % d.reverse)

          if repeaters[4] then
            d[4].succ!
            t = Time.parse(TF % d.reverse)
          end
        elsif t.day < @to_time.day and raw_a[3] == '*' then

          # increment the month
          if d[3].to_i <= 11 then
            d[3].succ!
          else 
            d[3] = '1'
            d[4].succ!
          end
          t = Time.parse(TF % d.reverse)
        elsif  (t.hour < @to_time.hour or (t.hour == @to_time.hour \
          and t.min < @to_time.min and raw_a[1] != '*') ) \
            and raw_a[2] == '*' then

          # increment the day
          t += DAY * ((@to_time.day - d[2].to_i) + 1)
        #jr070713 elsif t.min < @to_time.min and raw_a[1] == '*' then
        elsif t.min < @to_time.min and raw_a[1] == '*' then

          # increment the hour
          t += HOUR * ((@to_time.hour - d[1].to_i) + 1)
        elsif raw_a[0] == '*' then
          # increment the minute
          t += MINUTE * ((@to_time.min - d[0].to_i) + 1)
          t = procs.values[i].call(t, repeaters[i].to_i) if repeaters[i]
        end   

      end

      if wday then
        t += DAY until t.wday == wday.to_i
      end
      
      if t <= @to_time and repeaters.any? then

        repeaters.each_with_index do |x,i|
          if x then
            t = procs.values[i].call(t, x.to_i)
          end
        end
      end

      t     
    end

    @to_time = a.compact.min
  end
    
  def day_valid?(date)
    year, month, day = date
    last_day = DateTime.parse("%s-%s-%s" % [year, month.succ, 1]) - 1
    day.to_i <= last_day.day
  end  
  
end
