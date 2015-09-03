# Description:
#   Posts WMATA metro train disruptions to Slack.
#
# Dependencies:
#   node-schedule
#
# Configuration:
#   HUBOT_WMATA_KEY - API key.
#
# Commands:
#   hubot wmata - View current WMATA train incidents.
#
schedule = require 'node-schedule'

WMATA_URL = 'https://api.wmata.com/Incidents.svc/json/Incidents'
TOKEN_MISSING_MSG = 'HUBOT_WMATA_KEY is not set.'

module.exports = (robot) ->

  unless process.env.HUBOT_WMATA_KEY?
    robot.logger.warning TOKEN_MISSING_MSG

  # Every 30 minutes between 6AM-9AM, and 4PM-7PM (EST) Monday to Friday.
  recurrence = new schedule.RecurrenceRule()
  recurrence.dayOfWeek = [new schedule.Range(1, 5)]
  recurrence.hour = [new schedule.Range(10, 13), new schedule.Range(8, 11)]
  recurrence.minute = [0, 30]

  _request = (cb) ->
    robot.http(WMATA_URL)
      .header('api_key', process.env.HUBOT_WMATA_KEY)
      .request('GET') (err, res, body) ->

        # Example body.
        #
        # {
        #   "Incidents": [
        #     {
        #       "IncidentID": "A38CE731-E863-40A0-ABBB-79FEF304AC35",
        #       "Description": "Silver Line: Trains operate btwn Wiehle & McLe",
        #       "StartLocationFullName": null,
        #       "EndLocationFullName": null,
        #       "PassengerDelay": 0.0,
        #       "DelaySeverity": null,
        #       "IncidentType": "Alert",
        #       "EmergencyText": null,
        #       "LinesAffected": "SV;",
        #       "DateUpdated": "2015-08-07T23:53:39"
        #     },
        #     {
        #       "IncidentID": "14A1E88D-5251-4685-ABE2-9ED4848BFB24",
        #       "Description": "Silver Line: Free shuttle buses replace train ",
        #       "StartLocationFullName": null,
        #       "EndLocationFullName": null,
        #       "PassengerDelay": 0.0,
        #       "DelaySeverity": null,
        #       "IncidentType": "Alert",
        #       "EmergencyText": null,
        #       "LinesAffected": "SV;",
        #       "DateUpdated": "2015-08-07T23:52:53"
        #     }
        # }

        return cb err if err?

        data = JSON.parse body

        cb err, data

  _reportIncidents = (cb) ->
    _request (err, data) ->
      return cb(err, null) if err?

      data?.Incidents?.map (incident) ->

        fields = [
            title: incident.IncidentType
            value: incident.LinesAffected
            short: true
          ,
            title: 'Last Updated'
            value: incident.DateUpdated
            short: true
          ,
            title: 'Description'
            value: incident.Description
            short: false
        ]

        fallback = "#{incident.IncidentType} : #{incident.Description}"

        robot.emit 'slack-attachment',
          message:
            room:     'wmata'
            username: 'wmata'
          content:
            text:     ''
            color:    'danger'
            pretext:  ''
            fallback: fallback
            fields:   fields

      return cb(null, data.Incidents)

  schedule.scheduleJob recurrence, () ->
    _reportIncidents (err, incidents) ->
      # noop

  robot.respond /wmata$/i, (msg) ->
    _reportIncidents (err, incidents) ->
      unless incidents?
        msg.send 'WMATA returned no train disruptions.'
