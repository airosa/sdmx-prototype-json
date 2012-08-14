ws = require '../live-test-ws'


describe 'live-test-ws date functions', ->

    it 'converts standard time periods to dates in the beginning of the period', ->
        testPeriods = [
            [ 'A', 2000,   1,   2000,  0,  1 ]
            [ 'S', 2000,   1,   2000,  0,  1 ]
            [ 'T', 2000,   1,   2000,  0,  1 ]
            [ 'Q', 2000,   1,   2000,  0,  1 ]
            [ 'M', 2000,   1,   2000,  0,  1 ]
            [ 'W', 2000,   1,   2000,  0,  3 ]
            [ 'D', 2000,   1,   2000,  0,  1 ]
            [ 'S', 2012,   2,   2012,  6,  1 ]
            [ 'T', 2012,   3,   2012,  8,  1 ]
            [ 'Q', 2012,   4,   2012,  9,  1 ]
            [ 'M', 2012,  12,   2012, 11,  1 ]
            [ 'W', 2012,  52,   2012, 11, 24 ]
            [ 'D', 2012, 366,   2012, 11, 31 ]
        ]

        for p in testPeriods
            converted = ws.timePeriodToDate( p[0], p[1], p[2], false ).getTime()
            target = Date.UTC( p[3], p[4], p[5], 0, 0, 0 )
            converted.should.equal target 


    it 'converts standard time periods to dates in the beginning of the next period', ->
        testPeriods = [
            [ 'A', 2000,   1,   2001,  0,  1 ]
            [ 'S', 2000,   1,   2000,  6,  1 ]
            [ 'T', 2000,   1,   2000,  4,  1 ]
            [ 'Q', 2000,   1,   2000,  3,  1 ]
            [ 'M', 2000,   1,   2000,  1,  1 ]
            [ 'W', 2000,   1,   2000,  0, 10 ]
            [ 'D', 2000,   1,   2000,  0,  2 ]
            [ 'S', 2012,   2,   2013,  0,  1 ]
            [ 'T', 2012,   3,   2013,  0,  1 ]
            [ 'Q', 2012,   4,   2013,  0,  1 ]
            [ 'M', 2012,  12,   2013,  0,  1 ]
            [ 'W', 2012,  52,   2012, 11, 31 ]
            [ 'D', 2012, 366,   2013,  0,  1 ]
        ]

        for p in testPeriods
            converted = ws.timePeriodToDate( p[0], p[1], p[2], true ).getTime()
            target = Date.UTC( p[3], p[4], p[5], 0, 0, 0 )
            converted.should.equal target 


    it 'parses dates in all supported formats and returns the beginning of the parsed period', ->
        testPeriods = [
            [ '2000'      ,   2000,  0,  1 ]
            [ '2000-01'   ,   2000,  0,  1 ]
            [ '2000-12'   ,   2000, 11,  1 ]
            [ '2000-S2'   ,   2000,  6,  1 ]
            [ '2012-T2'   ,   2012,  4,  1 ]
            [ '2012-Q3'   ,   2012,  6,  1 ]
            [ '2012-M07'  ,   2012,  6,  1 ]
            [ '2012-W07'  ,   2012,  1, 13 ]
            [ '2012-02-29',   2012,  1, 29 ]
        ]

        for p in testPeriods
            converted = ws.parseDate( p[0], false ).getTime()
            target = Date.UTC( p[1], p[2], p[3], 0, 0, 0)
            converted.should.equal target

        testPeriods = [
            [ '2012-02-29T12:22:22'          ,   Date.UTC(2012,  1, 29, 12, 22, 22,   0) ]
            [ '2012-12-29T02:01:08Z'         ,   Date.UTC(2012, 11, 29,  2,  1,  8,   0) ]
            [ '2012-06-13T11:32:54.084'      ,   Date.UTC(2012,  5, 13, 11, 32, 54,  84) ]
            [ '2012-09-11T07:21:45.298+01:00',   Date.UTC(2012,  8, 11,  6, 21, 45, 298) ]
        ]

        for p in testPeriods
            converted = ws.parseDate( p[0], false ).getTime()
            converted.should.equal p[1]


    it 'parses dates and returns the end of the period', ->
        testPeriods = [
            [ '2000'      ,   Date.UTC( 2000, 11, 31, 23, 59, 59, 0 ) ]
            [ '2012-M02'  ,   Date.UTC( 2012,  1, 29, 23, 59, 59, 0 ) ]
            [ '2012-02'   ,   Date.UTC( 2012,  1, 29, 23, 59, 59, 0 ) ]
            [ '2012-06-14',   Date.UTC( 2012,  5, 14, 23, 59, 59, 0 ) ]
        ]

        for p in testPeriods
            converted = ws.parseDate( p[0], true ).getTime()
            converted.should.equal p[1]



