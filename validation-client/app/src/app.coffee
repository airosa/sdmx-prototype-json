validationApp = angular.module 'ValidationApp', []


validationApp.controller 'ValidationCtrl', ($scope, $http) ->
    $scope.schemaType = 'json-slice'
    $scope.messages = []
    $scope.state =
        httpError: false
        httpErrorData: false
        dataRequestRunning: false
        dimensionRequestRunning: false
    schema = {}


    $scope.validate = () ->
        $scope.messages = []
        requestSchema()


    requestSchema = () ->
        $scope.state.httpError = false
        $scope.state.running = true

        switch $scope.schemaType
            when 'json-slice' then schemaUrl = 'json-slice-schema.json'
            when 'json-code-index' then schemaUrl = 'json-code-index-schema.json'

        $scope.messages.push "Requesting schema from #{schemaUrl}"

        config =
            method: 'GET'
            url: schemaUrl
            cache: false
            transformResponse: (data) -> data

        $http(config).success(onSchema).error(onError)


    onSchema = (data, status, headers, config) ->
        $scope.state.testRunning = false
        $scope.state.httpError = false

        $scope.messages.push 'Received schema'
        $scope.messages.push 'Starting to parse schema'

        try
            schema = JSON.parse data
        catch error
            $scope.messages.push "Error: #{error}"
            return

        $scope.messages.push 'Finished parsing schema'

        $scope.state.testRunning = true

        $scope.messages.push "Requesting data from web service #{$scope.wsName}"

        config =
            method: 'GET'
            url: $scope.wsName
            cache: false
            transformResponse: (data) -> data

        $http(config).success(onData).error(onError)


    onData = (data, status, headers, config) ->
        $scope.state.testRunning = false
        $scope.state.httpError = false
        $scope.messages.push 'Received data from web service'
        $scope.messages.push 'Starting to parse data'

        try
            json = JSON.parse data
        catch error
            $scope.messages.push "ERROR: #{error}"
            return

        $scope.messages.push 'Finished parsing data'

        $scope.messages.push 'Starting to validate data'

        valid = tv4.validate json, schema

        $scope.messages.push JSON.stringify(tv4.error, null, 4) unless valid

        $scope.messages.push 'Finished validating data'


    onError = (data, status, headers, config) ->
        $scope.state.testRunning = false
        $scope.state.httpError = true

        $scope.response =
            status: status
            errors: data.errors





