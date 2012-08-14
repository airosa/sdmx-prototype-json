ws = require '../live-test-ws'
should = require 'should'


describe 'live-test-ws parsing functions', ->

    it 'parses data flow references', ->
        testData = [
            [ 'ECB,ECB_ICP1,1.0', { agencyID: 'ECB', id: 'ECB_ICP1', version:    '1.0' }, 200 ]
            [ 'ECB,ECB_ICP1',     { agencyID: 'ECB', id: 'ECB_ICP1', version: 'LATEST' }, 200 ]
            [ 'ECB_ICP1',         { agencyID: 'ALL', id: 'ECB_ICP1', version: 'LATEST' }, 200 ]
            [ 'A,B,C,D',                                                       undefined, 400 ]
        ]

        for f in testData
            req = { query: {} }
            res = { statusCode: 200, errors:[] }
            ws.parseFlowRef f[0], req, res
            res.statusCode.should.equal f[2]
            if f[1]?
                req.query.flowRef.should.eql f[1]
            else
                should.not.exist req.query.flowRef


    it 'parses data provider references', ->
        testData = [
            [ 'ECB,ECB',  { agencyID: 'ECB', id: 'ECB' }, 200 ]
            [ 'ALL,ECB',  { agencyID: 'ALL', id: 'ECB' }, 200 ]
            [ 'ECB',      { agencyID: 'ALL', id: 'ECB' }, 200 ]
            [ 'all',      { agencyID: 'ALL', id: 'ALL' }, 200 ]
            [ 'A,B,C',                         undefined, 400 ]
        ]

        for f in testData
            req = { query: {} }
            res = { statusCode: 200, errors:[] }
            ws.parseProviderRef f[0], req, res
            res.statusCode.should.equal f[2]
            if f[1]?
                req.query.providerRef.should.eql f[1]
            else
                should.not.exist req.query.providerRef


    it 'parses keys', ->
        testData = [
            [ 'all',   'all'                 , 200 ]
            [ 'A.B',   [ ['A'], ['B'] ]      , 200 ]
            [ 'A.B+C', [ ['A'], ['B', 'C'] ] , 200 ]
            [ 'A..',   [ ['A'], [ ], [ ] ]   , 200 ]
        ]

        for k in testData
            req = { query: {} }
            res = { statusCode: 200, errors:[] }
            ws.parseKey k[0], req, res
            res.statusCode.should.equal k[2]
            if k[1]?
                req.query.key.should.eql k[1]
            else
                should.not.exist req.query.key


    it 'parses query parameters', ->
        testData = [
            [ '?startPeriod=2012-09', { startPeriod: new Date '2012-09-01' }        , 200 ]
            [ '?endPeriod=2012-09',   { endPeriod: new Date '2012-09-30T23:59:59' } , 200 ]
            [ '?detail=nodata',       { detail: 'nodata' }                          , 200 ]
        ]

        for p in testData
            req = { url: p[0], query: {} }
            res = { statusCode: 200, errors:[] }
            ws.parseQueryParams req, res
            res.statusCode.should.equal p[2]
            if p[1]?
                req.query.should.eql p[1]
            else
                should.not.exist req.query



