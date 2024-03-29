#!/usr/bin/env ruby

# file: cron_format.rb

require 'date'
require 'time'
require 'c32'


MINUTE = 60
HOUR = MINUTE * 60
DAY = HOUR * 24
WEEK = DAY * 7
TF = "%s-%s-%s %s:%s"


class CronFormat
  using ColouredText

  attr_reader :to_time, :to_expression

  def initialize(cron_string, now=Time.now, debug: false)

    puts 'inside CronFormat'.info if debug
    @cron_string, @now, @debug = cron_string, now, debug
    @to_time = @now
    parse()

  end

  # supply a Time object. Modifying the date can be helpful when
  # triggering a day before an actual expression date e.g. the day
  # before the last sunday in March (British summer time).
  #
  def adjust_date(d)

    @to_time = d
    m, h, dd, mm, yy = @to_expression.split

    day = dd =~ /^\d+$/ ? d.day : dd
    month = mm =~ /^\d+$/  ? d.month : mm
    year = yy =~ /^\d+$/ ? d.year : yy

    @to_expression = [m, h, day, month, year].join(' ')

  end

  def next()

    nudge() #unless @cron_string =~ %r{/}
    #puts ':to_time : ' + @to_time.inspect
    parse(nudged: true)
  end

  private

  def nudge()

    t1 = @to_time
    puts ('t1: ' + t1.inspect).debug if @debug
    a  =  @cron_string.split

    val = if @cron_string =~ %r{[/,-]} then
      a.reverse.detect{|x| x[/[\/,-]/]}
    else
      a[1..-1].detect{|x| x != '*'}
    end

    index, n = 0, 1

    puts ('val: ' + val.inspect).debug if @debug

    if val then
      index = a.index(val)

      r = val[/,|\/(\d+)$/,1]

      n =  if r then

        index == 4 ? r.to_i * 7 : 0

      else

        if val =~ /[,-]/ then
          1
        else
          val.to_i
        end
      end
    end

    puts ('index: ' + index.inspect).debug if @debug

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

    if @debug then
      puts ('@to_time: ' + @to_time.inspect).debug
      puts ('n: ' + n.inspect).debug
    end

    r = units[index].call @to_time, n

    puts ('r: ' + r.inspect).debug if @debug

    @to_time = if n > 1 then

      # given day light savings, ensure the time fragment is preserved
      Time.new(r.year, r.month, r.day, t1.hour, t1.min)

    else
      r
    end
    #r += MINUTE  if r == t1

  end

  def parse(nudged: false)

    puts ('0. @to_time: ' + @to_time.inspect).debug if @debug

    raw_a = @cron_string.split
    raw_a << '*' if raw_a.length <= 5 # add the year?
    mins, hours, day, month, wday, year = raw_a[0..5]

    if day[/\d+/] and month[/\d+/] and year == '*' then
      @to_time += DAY until @to_time.day == day.to_i and \
                                                @to_time.month == month.to_i
    end

    puts ('1. @to_time: ' + @to_time.inspect).debug if @debug

    #

    if @debug then
      puts ('1.5 @to_time: ' + @to_time.inspect).debug
      puts ('hours: ' + hours.inspect).debug
      puts ('mins: ' + mins.inspect).debug
    end

    if mins[/^\d+$/] and hours[/^\d+$/] then

      if @to_time.to_date != @now.to_date then
        @to_time = Time.local(@to_time.year, @to_time.month, @to_time.day)
      end

      until (@to_time.min == mins.to_i and @to_time.hour == hours.to_i) \
          or (@to_time - 1).isdst != @to_time.isdst do

        puts ('1.7 @to_time: ' + @to_time.inspect).debug if @debug
        @to_time += MINUTE
      end
      @to_time -= MINUTE
    else

      if mins[/^\d+$/] then
        @to_time += MINUTE until @to_time.min == mins.to_i
        @to_time -= MINUTE
      end

      @to_time += HOUR until @to_time.hour == hours.to_i if hours[/^\d+$/]
    end

    puts ('2. @to_time: ' + @to_time.inspect).debug if @debug

    if wday[/^[0-6]$/] and @to_time.wday != wday.to_i then
      @to_time += DAY until @to_time.wday == wday.to_i
    end

    dayceiling = raw_a[2][/-(\d+)$/,1]

    if dayceiling and dayceiling.to_i <= @to_time.day then

      dt2 = @to_time.to_datetime
      next_month = dt2.next_month.month
      dt2 += 1 until dt2.month == next_month

      @to_time = dt2.to_time
    end

    puts ('3. @to_time: ' + @to_time.inspect).debug if @debug

    units = @to_time.to_a.values_at(1..4) + [nil, @to_time.year]

    procs = {
        min: lambda {|x, interval| x += (interval * MINUTE).to_i},
       hour: lambda {|x, interval| x += (interval * HOUR).to_i},
        day: lambda {|x, interval| x += (interval * DAY).to_i},
      month: lambda {|x, interval|
         date = x.to_a.values_at(1..5)
         interval.times { date[3].succ! }
         Time.parse(TF % date.reverse)},
       week: lambda {|x, interval| x += (interval * WEEK).to_i},
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


    if raw_a[4] != '*' then
      r = /(sun|mon|tues|wed|thurs|fri|satur|sun)(day)?|tue|thu|sat/i

      to_i = lambda {|x|
        a = Date::DAYNAMES
        a.index a.grep(/#{x}/i).first
      }
      raw_a[4].gsub!(r,&to_i)
      raw_units[4].gsub!(r,&to_i)
    end

    @to_expression = raw_a[0..4].join ' '

    raw_date = raw_units.map.with_index {|x,i| dt[i].call(x) }

    # expand the repeater

    ceil = {min: MINUTE, hour: 23, day: 31, month: 12}.values

    if repeaters.any? then
      repeaters.each_with_index do |x,i|

        next if i == 4

        if x and not raw_a[i][/^\*/] then
          raw_date[i] = raw_date[i].map {|y|
            (y.to_i...ceil[i]).step(x.to_i).to_a.map(&:to_s)
          }.flatten
        else
          raw_date[i]
        end
      end
    end

    dates = inflate(raw_date)

    puts ('dates: ' + dates.inspect).debug if @debug

    a = dates.map do |date|

      d = date.map{|x| x ? x.clone : nil}
      wday, year = d.pop(2)
      d << year

      next unless day_valid? d.reverse.take 3
      t = Time.parse(TF % d.reverse)
      # if there is a defined weekday, increment a day at
      #                          a time to match that weekday
      if wday and wday != t.wday then

        t = Time.parse(TF % d.reverse)

        if repeaters[4] then
          t += repeaters[4].to_i * WEEK while t < @to_time
        else
          d[2], d[3] = @to_time.to_a.values_at(3,4).map(&:to_s)
          t += DAY until t.wday == wday.to_i
        end

      end

      # increment the month, day, hour, and minute for
      #              expressions which match '* * * *' consecutively
      i = 3

      while t < @to_time and i >= 0 and raw_a[i][/\*/]

        d[i] = @to_time.to_a[i+1].to_s
        t = Time.parse(TF % d.reverse)
        i -= 1
      end

      # starting from the biggest unit, attempt to increment that
      #                       unit where it is equal to '*'

      if @debug then
        puts ('t: ' + t.inspect).debug
        puts ('@to_time: ' + @to_time.inspect).debug
      end

      if t < @to_time then

        if t.month < @to_time.month and raw_a[4] == '*' then

          # increment the year
          d[4].succ!
          t = Time.parse(TF % d.reverse)
          puts 't: ' + t.inspect if @debug

          if repeaters[4] then

            d[4].succ!
            t = Time.parse(TF % d.reverse)
          end
        elsif t.day < @to_time.day and raw_a[3] == '*' then

          t = increment_month d
        elsif  (t.hour < @to_time.hour or (t.hour == @to_time.hour \
          and t.min < @to_time.min and raw_a[1] != '*') ) \
            and raw_a[2] == '*' then

          puts 'incrementing the day' if @debug
          # increment the day
          t += DAY * ((@to_time.day - d[2].to_i) + 1)
        elsif t.min < @to_time.min and raw_a[1] == '*' then

          # increment the hour
          t += HOUR * ((@to_time.hour - d[1].to_i) + 1)
        elsif raw_a[0][0] == '*' then

          i = 0

          # increment the minute
          t += MINUTE * ((@to_time.min - d[0].to_i) + 1)
          t = procs.values[i].call(t, repeaters[i].to_i) if repeaters[i]
        elsif raw_a[3] == '*' then

          t = increment_month d
        end

      end

      # after the units have been incremented we need to
      #                   increment the weekday again if need be
      if wday then

        if raw_date[2].length > 1 then

          t += DAY until t.wday == wday.to_i and raw_date[2].include? t.day.to_s
        else
          t += DAY until t.wday == wday.to_i
        end

      end

      if @debug then
        puts ('2. t: ' + t.inspect).debug
        puts ('2. @to_time: ' + @to_time.inspect).debug
      end

      # finally, if the date is still less than the current time we can
      #      increment the date using any repeating intervals
      if (t < @to_time or (!nudged and t == @to_time)) and repeaters.any? then

        repeaters.each_with_index do |x,i|

          if x then
            t = procs.values[i].call(t, x.to_i)
          end
        end
      end

      t
    end

    puts ('a: ' + a.inspect).debug if @debug

    @to_time = a.compact.min
  end

  def day_valid?(date)

    year, month, day = date
    last_day = DateTime.parse("%s-%s-%s" % [year,
                      (month.to_i < 12 ? month.succ : 1), 1]) - 1
    day.to_i <= last_day.day
  end

  def increment_month(d)

    puts 'inside increment_month' if @debug

    if d[3].to_i <= 11 then
      d[3].succ!
    else
      d[3] = '1'
      d[4].succ!
    end

    Time.parse(TF % d.reverse)
  end

  def inflate(raw_a)

    a = Array.new raw_a

    Array.new(a.max_by {|x| x.length}.length).map do |x|
      a.map{|x| x.length <= 1 ? x.first : x.shift}
    end
  end

end
