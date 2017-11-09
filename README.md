# Search Analytics Reporting Export

[![Build Status](https://travis-ci.org/NYPL/search-analytics-report-creator.svg?branch=master)](https://travis-ci.org/NYPL/search-analytics-report-creator)

This application generates reports of our click & search events.
It can be given an arbitrary start and end date.

It currently supports writing the report to disk and may
support other "outputs" in the future. For example: google-sheets or
a kinesis stream.

## Install & Running Locally

* This repo uses rvm and expects you to `bundle install` dependencies.

* It expects a valid file in `/config/google_auth.json`. That file is generated
by google. You can see what it looks like in [google_auth.example.json](config/google_auth.example.json)

## Running Locally

Use the `-h` flag for usage instructions.

```
$ ruby script/create_analytics_report.rb -h

USAGE: ruby ./script/create_analytics_reports.rb [options]
    -i, --id ID                      Google Analytics profile id in the form ga:XXXX where XXXX is the Analytics view (profile) ID
    -a path/to/auth/file.json,       path to file that contains google API account info and private_key
        --auth-file
    -s, --start-date STARTDATE       Start date of the report. Formatting can be found here: https://developers.google.com/analytics/devguides/reporting/core/v3/reference#startDate
    -e, --end-date ENDDATE           End date of the report. Formatting can be found here: https://developers.google.com/analytics/devguides/reporting/core/v3/reference#endDate
    -o, --output OUTPUT              output can be: /path/to/a/dir/ or "google-sheets"
    -g PARENTFOLDERID,               id of google drive folder to put report in
        --google-parent-id
    -h, --help                       Prints this help
```

Examples: 

`ruby script/create_analytics_report.rb --id ga:xxx --auth-file ./config/google_auth.json --start-date 2017-10-26 --end-date 2017-11-02 -o ~/Desktop/`

`ruby script/create_analytics_report.rb --id ga:xxx --auth-file ./config/google_auth.json --start-date 2017-10-26 --end-date 2017-11-02 -o google-sheets --google-parent-id SomeGoogleParentFolderId`

## Docker

## Building & Pushing to AWS ECR

We host our built images on [Amazon ECR](https://aws.amazon.com/ecr/).

1. "log in" to ECR:  `aws ecr get-login --no-include-email --region us-east-1 --profile [ACCOUNT-NAME] | /bin/bash`
If you receive an "Unknown options: --no-include-email" error, install the latest version of the AWS CLI.

1.  Build your image `docker build --no-cache -t nypl/search-analytics-report-creator:[TAGNAME] .`
You **MUST NOT** use an existing tag name. You must increment its semver.
You can skip this step if your image is already built.

1.  Link your local tag to the remote one: `docker tag nypl/search-analytics-report-creator:[TAGNAME] [ACCOUNT-ID].dkr.ecr.us-east-1.amazonaws.com/nypl/search-analytics-report-creator:[TAGNAME]`

1.  Actually push: `docker push nypl/search-analytics-report-creator:[TAGNAME]`

### Running locally from built docker image

And use `--env-file` flag to run Docker image with corresponding environment variable file.

`docker run --env-file config/.env.sample [name-or-id-of-docker-image]`


## Deploying

Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
