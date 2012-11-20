demoModule.controller 'MainCtrl', ($scope, $http) ->
    $scope.version = '0.2.0'

    $scope.state =
        httpError: false
        httpErrorData: false
        dataRequestRunning: false
        dimensionRequestRunning: false

    $scope.wsName = 'http://live-test-ws-2.nodejitsu.com'
    #$scope.wsName = 'http://localhost:8081'
    #$scope.wsName = 'http://46.137.144.117/FusionCube/ws'

    $scope.dfName = 'ECB_ICP1'
    #$scope.dfName = 'IMF,PGI,1.0'

    $scope.key = ''
    #$scope.key = '....'

    $scope.customParams = ''
    #$scope.customParams = 'format=samistat'

    $scope.show = 'data'

    $scope.showMetadata = false

    $scope.refreshRuntime = null

    $scope.responseVersion = null


#-------------------------------------------------------------------------------

    class JSONSeriesCube
        constructor: (@_msg) ->
            @dimensions = @_msg.dimensions
            @obsAttributes = @_msg.attributes.obsAttributes

            for attrId, i in @obsAttributes
                @_msg.attributes[attrId].obsAttributesIndex = i

            # sort the data array in place
            @_msg.data.sort @dataObjectOrder
            for obj in @_msg.data
                continue unless obj.observations?
                obj.observations.sort @observationOrder

        observationOrder: (a, b) ->
            return -1 if a[0] < b[0]
            return 1 if b[0] < a[0]
            0

        objectKeyOrder: (a, b) ->
            for val, i in a
                continue if a[i] is b[i]
                return -1 if a[i] is null
                return 1 if b[i] is null
                return -1 if a[i] < b[i]
                return 1
            0

        dataObjectOrder: (a, b) =>
            return -1 if not a.dimensions? and b.dimensions?
            return 1 if a.dimensions? and not b.dimensions?
            return 0 if not a.dimensions? and not b.dimensions?
            @objectKeyOrder a.dimensions, b.dimensions

        dataObjectBinarySearch: (key) ->
            startIndex  = 0
            stopIndex = @_msg.data.length - 1
            middleIndex = Math.floor( (stopIndex + startIndex) / 2 )
            order = null

            while startIndex <= stopIndex
                order = @objectKeyOrder key, @_msg.data[middleIndex].dimensions
                if order < 0
                    stopIndex = middleIndex - 1
                else if 0 < order
                    startIndex = middleIndex + 1
                else
                    return @_msg.data[middleIndex]
                middleIndex = Math.floor((stopIndex + startIndex)/2)

            undefined

        observationBinarySearch: (observations, period) ->
            startIndex  = 0
            stopIndex = observations.length - 1
            middleIndex = Math.floor( (stopIndex + startIndex) / 2 )

            while startIndex <= stopIndex
                if period < observations[middleIndex][0]
                    stopIndex = middleIndex - 1
                else if observations[middleIndex][0] < period
                    startIndex = middleIndex + 1
                else
                    return observations[middleIndex]
                middleIndex = Math.floor((stopIndex + startIndex)/2)

            undefined

        attribute: (id) ->
            @_msg.attributes[id]

        observationSearch: (key) ->
            obj = @dataObjectBinarySearch key[0...-1]
            return undefined unless obj?
            return undefined unless obj.observations?
            period = key[ key.length - 1 ]
            observation = @observationBinarySearch obj.observations, period

        observationValue: (key) ->
            observation = @observationSearch key
            return undefined unless observation?
            observation[1]

        attributeValue: (id, key) ->
            attrVal = {}
            attr = @_msg.attributes[id]

            if attr.obsAttributesIndex?
                #observation level attribute
                observation = @observationSearch key
                return undefined unless observation?
                attrVal.value = observation[attr.obsAttributesIndex + 2]
            else
                #series level attribute
                obj = @dataObjectBinarySearch key[0...-1]
                return undefined unless obj? and obj.attributes?
                attrVal.value = obj.attributes[id]

            attrVal.value ?= attr.default
            return undefined unless attrVal.value?
            attrVal.name = attr.codes[attrVal.value].name if attr.codes?
            attrVal

#-------------------------------------------------------------------------------

    class JSONArrayCube
        constructor: (@_msg) ->
            @dimensions = @_msg.dimensions
            @obsAttributes = []
            @_multipliers = []

            # calculate and store multipliers for measure index calculations
            @_msg.dimensions.multipliers = []
            prev = 1
            for dim in @_msg.dimensions.id.slice().reverse()
                @_msg.dimensions.multipliers.push prev
                prev *= @_msg.dimensions[dim].codes.length
            @_msg.dimensions.multipliers.reverse()

            # calculate and store multipliers for attribute value index calculations
            for attrId in @_msg.attributes.id
                attr = @_msg.attributes[attrId]
                attr.multipliers = []
                prev = 1
                for dim in attr.dimension.slice().reverse()
                    attr.multipliers.push prev
                    prev *= @_msg.dimensions[dim].codes.length
                attr.multipliers.reverse()

            prev = 1
            for dimId in @dimensions.id.slice().reverse()
                @_multipliers.push prev
                prev *= @dimensions[dimId].codes.length
            @_multipliers.reverse()

            for attrId in @_msg.attributes.id
                attr = @_msg.attributes[attrId]
                if attr.dimension.length is @dimensions.id.length
                    @obsAttributes.push attrId

        attribute: (id) ->
            @_msg.attributes[id]

        observationValue: (key) ->
            #return key
            index = 0
            for codeIndex, j in key
                index += codeIndex * @_multipliers[j]
            @_msg.measure[index]

        attributeValue: (id, key) ->
            #return undefined
            attrVal = {}
            attributes = @_msg.attributes

            attr = @_msg.attributes[id]
            return undefined unless attr?

            index = 0
            for dim, j in attr.dimension
                index += key[@dimensions[dim].index] * attr.multipliers[j]
            attrVal.value = attr.value[index]
            attrVal.value ?= attr.default
            attrVal.name = attr.codes[attrVal.value].name if attr.codes?
            attrVal


#-------------------------------------------------------------------------------

    class PivotTable
        constructor: () ->
            @data = null
            @pageData = []
            @pageDims = []
            @rowDims = []
            @colDims = []

        newRow: () ->
            return { headers: [], data: [] }

        addHeadRow: () ->
            @headrows.push @row
            @row = @newRow()

        addBodyRow: () ->
            @bodyrows.push @row
            @row = @newRow()


        addHeaderCell: (value, rowspan = 1, colspan = 1) ->
            @row.headers.push { value: value, rowspan: rowspan, colspan: colspan }


        addDataCell: (key) ->
            val =
                decimals: @data.attributeValue 'DECIMALS', key
                obsVal: @data.observationValue key
                style:
                    'text-align': 'right'
                key: key.join ':'
                metadata: ''
                hclass: 'cell-normal'
                attributes: []

            if val.obsVal?
                if val.decimals? and val.obsVal isnt '-'
                    val.data = val.obsVal.toFixed val.decimals.value
                else
                    val.data = val.obsVal

            for attrId in @data.obsAttributes
                attr = @data.attributeValue attrId, key
                continue unless attr?
                val.attrName = @data.attribute(attrId).name
                val.attributes.push attr
                val.metadata += ', ' if 0 < val.metadata.length
                val.metadata += @data.attribute(attrId).name + ': '
                val.metadata += if attr.name? then attr.name else attr.value

            if $scope.show is 'metadata'
                val.value = val.metadata
            else
                val.value = val.data

            @row.data.push val


        pivotRow: (pos) ->
            if pos is 0
                @colDims.splice 0, 0, @rowDims.shift()
            else
                tmp = @rowDims[pos]
                @rowDims[pos] = @rowDims[pos-1]
                @rowDims[pos-1] = tmp

            @rebuild()


        pivotCol: (pos) ->
            if pos is @colDims.length - 1
                @rowDims.push @colDims.pop()
            else
                tmp = @colDims[pos]
                @colDims[pos] = @colDims[pos-1]
                @colDims[pos-1] = tmp

            @rebuild()


        build: (data) ->
            @data = data

            @pageDims = []
            @pageData = []
            @obsAttributes = []

            for dimId in @data.dimensions.id
                dim = @data.dimensions[dimId]

                rowPos = @rowDims.indexOf dim.id
                colPos = @colDims.indexOf dim.id

                # if a dimension has only one value store in separately for display
                if dim.codes.length is 1
                    @pageDims.push dim.id
                    @pageData.push {
                        name: dim.name
                        value: dim.codes[0].name
                    }

                    @rowDims.splice rowPos, 1 if -1 < rowPos
                    @colDims.splice colPos, 1 if -1 < colPos

                    continue

                continue if -1 < rowPos or -1 < colPos

                if @rowDims.length is 0
                   @rowDims.push dim.id
                   continue

                if @colDims.length is 0
                   @colDims.push dim.id
                   continue

                @rowDims.push dim.id

            @rebuild()


        visualize: () ->
            return unless $scope.show is 'dataColors'

            max = null
            min = null
            for row in @bodyrows
                for cell in row.data
                    continue unless cell.obsVal?
                    max = cell.obsVal unless max?
                    min = cell.obsVal unless min?
                    max = cell.obsVal if max < cell.obsVal
                    min = cell.obsVal if cell.obsVal < min

            range = max - min
            for row in @bodyrows
                for cell in row.data
                    continue unless cell.obsVal
                    opacity = 1 - ((max - cell.obsVal) / range)
                    cell.style.background = 'rgba(70,136,71,' + opacity + ')'


        rebuild: () ->
            start = new Date()
            @headrows = []
            @bodyrows = []
            @row = @newRow()

            colSteps = []
            colLengths = []
            colCount = 1
            for dimId in @colDims.slice().reverse()
                colSteps.push colCount
                length = @data.dimensions[dimId].codes.length
                colCount *= length
                colLengths.push length
            colSteps.reverse()
            colLengths.reverse()

            rowSteps = []
            rowLengths = []
            rowCount = 1
            for dimId in @rowDims.slice().reverse()
                rowSteps.push rowCount
                length = @data.dimensions[dimId].codes.length
                rowCount *= length
                rowLengths.push length
            rowSteps.reverse()
            rowLengths.reverse()

            @addHeaderCell null, @colDims.length, @rowDims.length

            if @colDims.length is 0
                @addHeaderCell null
                @addHeadRow()
            else
                for dimId, i in @colDims
                    repeat = if i is 0 then 1 else colLengths[i-1]
                    for j in [0...repeat]
                        for code in @data.dimensions[dimId].codes
                            @addHeaderCell code.name, 1, colSteps[i]
                    @addHeadRow()

            cellkey = []
            for i in [0...@data.dimensions.id.length]
                cellkey[i] = 0

            if @rowDims.length is 0
                @addHeaderCell null
                for j in [0...colCount]
                    for dimId, k in @colDims
                        dim = @data.dimensions[dimId]
                        codeIndex = Math.floor( j / colSteps[k] ) % colLengths[k]
                        cellkey[dim.index] = codeIndex
                    @addDataCell cellkey
                @addBodyRow()
            else
                for i in [0...rowCount]
                    for dimId, j in @rowDims
                        dim = @data.dimensions[dimId]
                        codeIndex = Math.floor( i / rowSteps[j] ) % rowLengths[j]
                        codeIndexPrev = Math.floor( (i - 1) / rowSteps[j] ) % rowLengths[j]
                        cellkey[dim.index] = codeIndex

                        if codeIndex isnt codeIndexPrev
                            code = @data.dimensions[dimId].codes[codeIndex]
                            @addHeaderCell code.name, rowSteps[j], 1

                    for j in [0...colCount]
                        for dimId, k in @colDims
                            dim = @data.dimensions[dimId]
                            codeIndex = Math.floor( j / colSteps[k] ) % colLengths[k]
                            cellkey[dim.index] = codeIndex

                        @addDataCell cellkey

                    @addBodyRow()

            @visualize()

            $scope.refreshRuntime = new Date() - start


    $scope.pivotTable = new PivotTable()

#-------------------------------------------------------------------------------
# Code for making requests to the WS

    $scope.getDimensions = () ->
        $scope.state.httpError = false
        $scope.state.dimensionRequestRunning = true
        $http.get( $scope.dimUrl, { withCredentials: true } ).success(onDimensions).error(onError)


    $scope.getData = () ->
        headers = headers: {}
        $scope.startRequest = new Date()
        $scope.state.httpErrorData = false
        $scope.state.dataRequestRunning = true
        $http.get( $scope.dataUrl, { withCredentials: true } ).success(onData).error(onErrorData)

#-------------------------------------------------------------------------------
# Code for handling responses to requests

    onDimensions = (data, status, headers, config) ->
        $scope.state.dimensionRequestRunning = false
        $scope.state.httpError = false

        $scope.responseVersion = data['sdmx-proto-json']

        $scope.pivotTable = new PivotTable()

        $scope.response =
            status: status
            headers: headers

        dimensions = $scope.dimensions = data.dimensions

        dimensions.seriesKeyDims = []
        if data['sdmx-proto-json'] is '2012-09-13'
            for dimId in dimensions.id
                dim = dimensions[dimId]
                codes = []
                for codeId, i in dim.codes.id
                    code = dim.codes[codeId]
                    code.order = i
                    codes.push code
                dim.codes = codes

        for dimId in dimensions.id
            dim = dimensions[dimId]
            dimensions.seriesKeyDims.push dimId

            if dim.type is 'time'
                dimensions.timeDimension = dim

            for code in dim.codes
                code.checked = false
                if dim.type is 'time'
                    dimensions.timeDimension = dim
                    code.start = new Date code.start
                    code.end = new Date code.end

            dim.codes[0].checked = true
            if 1 < dim.codes.length
                dim.codes[1].checked = true
            dim.show = false

        $scope.changeCheckedCodes()


    onData = (data, status, headers, config) ->
        $scope.requestRuntime = new Date() - $scope.startRequest
        $scope.state.httpErrorData = false
        $scope.state.dataRequestRunning = false

        $scope.response =
            status: status
            headers: headers
            errors: []

        $scope.data = data
        data.commonDimensions = []
        data.tableDimensions = rows: [], cols: []

        if data['sdmx-proto-json'] is '2012-09-13'
            for dimId in data.dimensions.id
                dim = data.dimensions[dimId]
                codes = []
                for codeId, i in dim.codes.id
                    code = dim.codes[codeId]
                    code.order = i
                    codes.push code
                dim.codes = codes

        for dimId in data.dimensions.id
            dim = data.dimensions[dimId]
            if dim.type is 'time'
                data.dimensions.timeDimension = dim
                for code in dim.codes
                    # convert date strings to Javascript dates
                    code.start = new Date code.start
                    code.end = new Date code.end

        switch data['sdmx-proto-json']
            when '2012-09-13'
                $scope.pivotTable.build new JSONArrayCube(data)
            when '2012-11-15'
                $scope.pivotTable.build new JSONSeriesCube(data)
            else
                $scope.state.httpErrorData = true
                $scope.response.errors.push "Unsupported response version #{data['sdmx-proto-json']}"


#-------------------------------------------------------------------------------
# Code for handling request errors

    onError = (data, status, headers, config) ->
        $scope.state.dimensionRequestRunning = false
        $scope.state.httpError = true
        $scope.response =
            status: status
            headers: headers
            errors: data.errors


    onErrorData = (data, status, headers, config) ->
        $scope.state.dataRequestRunning = false
        $scope.state.httpErrorData = true
        $scope.response =
            status: status
            headers: headers
            errors: data.errors


#-------------------------------------------------------------------------------
# Code for the UI

    $scope.pivotRow = (pos) ->
        $scope.pivotTable.pivotRow pos


    $scope.pivotCol = (pos) ->
        $scope.pivotTable.pivotCol pos


    $scope.showButtonText = (show) ->
        if show
            return 'Hide'
        else
            return 'Show'


    $scope.changeDimUrl = () ->
        $scope.dimUrl = "#{$scope.wsName}/data/#{$scope.dfName}"

        if $scope.key.length
            $scope.dimUrl += "/#{$scope.key}"

        params = []
        params.push "detail=serieskeysonly"
        params.push $scope.customParams if $scope.customParams.length
        $scope.dimUrl += "?" + params.join '&' if params.length

    $scope.changeDimUrl()


    $scope.changeCheckedCodes = () ->
        dimensions = $scope.dimensions
        for dimId in dimensions.id
            dim = dimensions[dimId]
            dim.codes.checked = []
            for code in dim.codes
                dim.codes.checked.push code.id if code.checked

        $scope.changeDataUrl()


    $scope.changeDataUrl = () ->
        $scope.dataUrl = "#{$scope.wsName}/data/#{$scope.dfName}"

        key = []
        dimensions = $scope.dimensions
        for dimId, i in dimensions.id
            dim = dimensions[dimId]
            continue if dim.type is 'time'
            key.push dim.codes.checked

        for codes, i in key
            key[i] = codes.join '+'

        $scope.dataUrl += '/' + key.join '.'

        periods = calculateStartAndEndPeriods $scope.dimensions.timeDimension

        params = []
        params.push periods if periods.length
        if $scope.responseVersion is '2012-11-15'
            params.push "dimensionAtObservation=TIME_PERIOD"
        else
            params.push "dimensionAtObservation=AllDimensions"
        params.push $scope.customParams if $scope.customParams.length
        $scope.dataUrl += '?' + params.join '&' if params.length


    calculateStartAndEndPeriods = (timeDimension) ->
        startPeriod = null
        endPeriod = null
        params = ''

        for code in timeDimension.codes
            continue unless code.checked

            if startPeriod?
                if code.start < startPeriod.start
                    startPeriod = code
            else
                startPeriod = code

            if endPeriod?
                if endPeriod.end < code.end
                    endPeriod = code
            else
                endPeriod = code

        if startPeriod?
            params = 'startPeriod=' + startPeriod.id

        if endPeriod?
            params += '&endPeriod=' + endPeriod.id

        params


    return
