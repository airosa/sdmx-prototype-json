demoModule.controller 'MainCtrl', ($scope, $http) ->
    $scope.version = '0.1.4'

    $scope.state =
        httpError: false
        httpErrorData: false
        dataRequestRunning: false
        dimensionRequestRunning: false

    $scope.wsName = 'http://live-test-ws.nodejitsu.com'
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

#-------------------------------------------------------------------------------

    class JSONArrayCube 
        constructor: (@_msg) ->
            @dimensions = @_msg.dimensions
            @obsAttributes = []            
            @_multipliers = []

            prev = 1
            for dimId in @dimensions.id.slice().reverse()
                @_multipliers.push prev
                prev *= @dimensions[dimId].codes.id.length
            @_multipliers.reverse()

            for attrId in @_msg.attributes.id
                attr = @_msg.attributes[attrId]
                if attr.dimension.length is @dimensions.id.length
                    @obsAttributes.push attrId

        attribute: (id) ->
            @_msg.attributes[id]
 
        observationValue: (key) ->
            index = 0
            for codeIndex, j in key
                index += codeIndex * @_multipliers[j]
            @_msg.measure[index]

        attributeValue: (id, key) ->
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
                if val.decimals?
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
                if dim.codes.id.length is 1
                    @pageDims.push dim.id
                    @pageData.push {
                        name: dim.name
                        value: dim.codes[dim.codes.id[0]].name
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
                length = @data.dimensions[dimId].codes.id.length
                colCount *= length
                colLengths.push length
            colSteps.reverse()
            colLengths.reverse()

            rowSteps = []
            rowLengths = []
            rowCount = 1
            for dimId in @rowDims.slice().reverse()
                rowSteps.push rowCount
                length = @data.dimensions[dimId].codes.id.length
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
                        for id in @data.dimensions[dimId].codes.id
                            @addHeaderCell @data.dimensions[dimId].codes[id].name, 1, colSteps[i]
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
                            code = @data.dimensions[dimId].codes.id[codeIndex]
                            @addHeaderCell @data.dimensions[dimId].codes[code].name, rowSteps[j], 1

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

        $scope.pivotTable = new PivotTable()

        $scope.response =
            status: status
            headers: headers

        dimensions = $scope.dimensions = data.dimensions

        dimensions.seriesKeyDims = []
        for dimId in dimensions.id
            dim = dimensions[dimId]
            
            dimensions.seriesKeyDims.push dimId

            if dim.type is 'time'
                dimensions.timeDimension = dim

            for codeId in dim.codes.id
                code = dim.codes[codeId]
                code.checked = false
                if dim.type is 'time'
                    dimensions.timeDimension = dim
                    code.start = new Date code.start
                    code.end = new Date code.end

            dim.codes[dim.codes.id[0]].checked = true
            if 1 < dim.codes.id.length
                dim.codes[dim.codes.id[1]].checked = true
            dim.show = false

        $scope.changeCheckedCodes()


    onData = (data, status, headers, config) ->
        $scope.requestRuntime = new Date() - $scope.startRequest
        $scope.state.httpErrorData = false
        $scope.state.dataRequestRunning = false

        $scope.response =
            status: status
            headers: headers

        $scope.data = data
        data.commonDimensions = []
        data.tableDimensions = rows: [], cols: []
        for dimId in data.dimensions.id
            dim = data.dimensions[dimId]
            
            if dim.type is 'time'
                data.dimensions.timeDimension = dim
                for codeId in dim.codes.id
                    code = dim.codes[codeId]
                    # convert date strings to Javascript dates
                    code.start = new Date code.start
                    code.end = new Date code.end
 
        # calculate and store multipliers for measure index calculations
        data.dimensions.multipliers = []
        prev = 1
        for dim in data.dimensions.id.slice().reverse()
            data.dimensions.multipliers.push prev
            prev *= data.dimensions[dim].codes.id.length
        data.dimensions.multipliers.reverse()

        # calculate and store multipliers for attribute value index calculations
        for attrId in data.attributes.id
            attr = data.attributes[attrId]
            attr.multipliers = []
            prev = 1
            for dim in attr.dimension.slice().reverse()
                attr.multipliers.push prev
                prev *= data.dimensions[dim].codes.id.length
            attr.multipliers.reverse()

        $scope.pivotTable.build new JSONArrayCube(data)

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
            for codeId in dim.codes.id
                code = dim.codes[codeId]
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
        params.push "dimensionAtObservation=AllDimensions"
        params.push $scope.customParams if $scope.customParams.length
        $scope.dataUrl += '?' + params.join '&' if params.length


    calculateStartAndEndPeriods = (timeDimension) ->
        startPeriod = null
        endPeriod = null
        params = ''
        
        for codeId in timeDimension.codes.id
            code = timeDimension.codes[codeId]
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
