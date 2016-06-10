# Shirley

Simple Ruby module that monitores Linux server and pushes notifications to Slack. 

The `Observer` class should be run from `sudo crontab -e` minutely (or so), it fires only when limits are broken.

`ApacheUbuntu1404` or `ApacheCentos7` are under `Slackpush` and send a report - run it from `sudo crontab -e` daily.

![output](https://ibin.co/2kCmzt0Epqqh.jpg)

It appends a fortune cookie to the daily reports. 

![cookie](https://ibin.co/2kCntSdodFYc.jpg)

## Setting up Slack

1/ Log in to your Slack from browser (or create new Slack)
2/ In api.slack.com should be an option Incoming Hooks.. [https://api.slack.com/incoming-webhooks](https://api.slack.com/incoming-webhooks)
3/ Create a new incoming hook#
4/ Copy the URI it gives you. This is what you pass as the only variable to both the Observer and the Slackpush.

## Example

Report (daily)

```
require_relative("mod_shirley.rb")
include Shirley
hook = "https://hooks.slack.com/services/yyyyyyy/tttttt/ffffffffffff"
Shirley::ApacheCentos7.new(hook).worker
```

Observer (minutely)

```
require_relative("mod_shirley.rb")
include Shirley
hook = "https://hooks.slack.com/services/yyyyyyy/tttttt/ffffffffffff"
Shirley::Observer.new(hook).periodiccheck
```

## Required gems

Should be all standard in modern Rubies:

```
  require "net/http"
  require "uri"
  require "json"
  require "net/https"
```
