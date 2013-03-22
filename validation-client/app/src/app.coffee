validationApp = angular.module 'ValidationApp', []


validationApp.controller 'ValidationCtrl', ($scope, $http) ->
    $scope.schemaType = 'json-slice'
    $scope.messages = []
    schema = {}


    $scope.validate = () ->
        $scope.messages = []
        requestSchema()


    requestSchema = () ->
        switch $scope.schemaType
            when 'json-slice' then schemaUrl = 'https://raw.github.com/sdmx-twg/sdmx-prototype-json/master/json-slice/tools/schemas/json-slice-schema.json'
            when 'json-code-index' then schemaUrl = 'https://raw.github.com/sdmx-twg/sdmx-prototype-json/master/json-code-index/tools/schemas/json-code-index-schema.json'

        info "Requesting schema from #{schemaUrl}"

        config =
            method: 'GET'
            url: schemaUrl
            cache: false
            transformResponse: (data) -> data

        $http(config).success(onSchema).error(onError)


    onSchema = (data, status, headers, config) ->
        info 'Received schema'
        info 'Starting to parse schema'

        try
            schema = JSON.parse data
        catch error
            severe error
            return

        info 'Finished parsing schema'
        info "Requesting data from #{$scope.wsName}"

        config =
            method: 'GET'
            url: $scope.wsName
            cache: false
            transformResponse: (data) -> data

        $http(config).success(onData).error(onError)


    onData = (data, status, headers, config) ->
        info 'Received data from web service'
        info 'Starting to parse data'

        try
            json = JSON.parse data
        catch error
            severe error
            return

        info 'Finished parsing data'
        info 'Starting to validate data'

        valid = tv4.validate json, schema

        severe JSON.stringify(tv4.error, null, 4) unless valid

        info 'Finished validating data'
        info 'Done'


    onError = (data, status, headers, config) ->
        try
            json = JSON.parse data
            severe "#{status} #{json.errors}"
        catch err
            severe status


    info = (msg) -> log 'muted', msg

    severe = (msg) -> log 'text-error', "Error: #{msg}"

    log = (style, msg) -> $scope.messages.push class: style, msg: (new Date()).toISOString()[11..22] + ' ' + msg





