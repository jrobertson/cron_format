Introducing the cron_format gem

The cron_format gem accepts a cron expression and returns a time.

    require 'cron_format'

    cron_entry = '1 * * * *'
    date1 = Time.parse('2013-07-07 15:19:00 +0100')
    cf = CronFormat.new(cron_entry, date1)
    cf.to_time.strftime("%Y-%m-%d %H:%M")
    #=> "2013-07-07 16:01"

    CronFormat.new('1 15 * * *', Time.parse('2013-07-07 15:19:00')).to_time
    #=> 2013-07-08 15:01:00 +0100

time gem cron_format cron
