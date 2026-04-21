component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

    function beforeAll() {
        super.beforeAll();

        addMatchers( "hyper.models.TestBoxMatchers" );

        variables.client = getInstance( "Subscriptions@cordial-sdk" );
        variables.hyper = variables.client.getHyperClient();
    }

    function afterAll() {
        variables.hyper.clearFakes();
    }

    function run() {
        describe( "Subscriptions", function() {
            beforeEach( function() {
                configureDefaultFakes();
                variables.client.setHyperClient( variables.hyper );
            } );

            it( "builds subscribe requests for each valid subscriber", function() {
                var result = variables.client.create(
                    listKey = "myList",
                    subscribers = [ "person1@example.com", "person2@example.com" ],
                    forceSubscribe = true,
                    maxConcurrency = 1
                );

                expect( result.total ).toBe( 2 );
                expect( result.success ).toBeTrue();
                expect( result.succeeded ).toBe( 2 );
                expect( result.failed ).toBe( 0 );
                expect( result.results ).toHaveLength( 2 );
                expect( result.results[ 1 ].subscriber ).toBe( "person1@example.com" );
                expect( result.results[ 1 ].success ).toBeTrue();
                expect( result.results[ 1 ].statusCode ).toBeGTE( 200 );
                expect( result.results[ 1 ].statusCode ).toBeLT( 300 );
                expect( result.results[ 2 ].subscriber ).toBe( "person2@example.com" );
                expect( result.results[ 2 ].success ).toBeTrue();
                expect( result.results[ 2 ].statusCode ).toBeGTE( 200 );
                expect( result.results[ 2 ].statusCode ).toBeLT( 300 );
                expect( variables.hyper ).toHaveSentCount( 2 );

                expect( variables.hyper ).toHaveSentRequest( function( req ) {
                    var body = req.getBody();
                    return req.getMethod() == "POST"
                    && req.getUrl() == "/v2/contacts"
                    && body.channels.email.address == "person1@example.com"
                    && body.channels.email.subscribeStatus == "subscribed"
                    && body.myList == true
                    && body.forceSubscribe == true;
                } );
            } );

            it( "omits forceSubscribe from payload when false or defaulted", function() {
                var result = variables.client.create( listKey = "myList", subscribers = [ "person@example.com" ] );

                expect( result.total ).toBe( 1 );
                expect( result.success ).toBeTrue();
                expect( variables.hyper ).toHaveSentCount( 1 );

                expect( variables.hyper ).toHaveSentRequest( function( req ) {
                    var body = req.getBody();
                    return req.getMethod() == "POST"
                    && req.getUrl() == "/v2/contacts"
                    && !structKeyExists( body, "forceSubscribe" );
                } );
            } );

            it( "builds cancel requests for each valid subscriber", function() {
                var result = variables.client.cancel(
                    listKey = "myList",
                    subscribers = [ "person1@example.com", "person2@example.com" ],
                    maxConcurrency = 2
                );

                expect( result.total ).toBe( 2 );
                expect( result.success ).toBeTrue();
                expect( result.succeeded ).toBe( 2 );
                expect( result.failed ).toBe( 0 );
                expect( result.results ).toHaveLength( 2 );
                expect( result.results[ 1 ].subscriber ).toBe( "person1@example.com" );
                expect( result.results[ 1 ].success ).toBeTrue();
                expect( result.results[ 1 ].statusCode ).toBeGTE( 200 );
                expect( result.results[ 1 ].statusCode ).toBeLT( 300 );
                expect( result.results[ 2 ].subscriber ).toBe( "person2@example.com" );
                expect( result.results[ 2 ].success ).toBeTrue();
                expect( result.results[ 2 ].statusCode ).toBeGTE( 200 );
                expect( result.results[ 2 ].statusCode ).toBeLT( 300 );
                expect( variables.hyper ).toHaveSentCount( 2 );

                expect( variables.hyper ).toHaveSentRequest( function( req ) {
                    var body = req.getBody();
                    return req.getMethod() == "PUT"
                    && req.getUrl().startsWith( "/v2/contacts/email:" )
                    && findNoCase( "person1", req.getUrl() )
                    && body.myList == false;
                } );
            } );

            it( "url encodes special characters for cancel endpoint email key", function() {
                var result = variables.client.cancel(
                    listKey = "myList",
                    subscribers = [ "first.last+promo%tag@example.com" ]
                );

                expect( result.total ).toBe( 1 );
                expect( result.success ).toBeTrue();
                expect( variables.hyper ).toHaveSentCount( 1 );

                expect( variables.hyper ).toHaveSentRequest( function( req ) {
                    var requestURL = req.getUrl();
                    return req.getMethod() == "PUT"
                    && findNoCase( "%25", requestURL )
                    && ( findNoCase( "%2B", requestURL ) || findNoCase( "+", requestURL ) );
                } );
            } );

            it( "throws for an empty list key", function() {
                expect( function() {
                    variables.client.create( listKey = "", subscribers = [ "person@example.com" ] );
                } ).toThrow( type = "cordial-sdk.InvalidListKey" );
            } );

            it( "throws for a whitespace-only list key", function() {
                expect( function() {
                    variables.client.cancel( listKey = "   ", subscribers = [ "person@example.com" ] );
                } ).toThrow( type = "cordial-sdk.InvalidListKey" );
            } );

            it( "throws for an empty subscriber array", function() {
                expect( function() {
                    variables.client.cancel( listKey = "myList", subscribers = [] );
                } ).toThrow( type = "cordial-sdk.InvalidSubscribers" );
            } );

            it( "returns failed results for invalid email values while still processing valid emails", function() {
                var result = variables.client.create(
                    listKey = "myList",
                    subscribers = [ "person@example.com", "invalid" ]
                );

                expect( result.total ).toBe( 2 );
                expect( result.success ).toBeFalse();
                expect( result.succeeded ).toBe( 1 );
                expect( result.failed ).toBe( 1 );
                expect( result.results ).toHaveLength( 2 );
                expect( result.results[ 1 ].subscriber ).toBe( "invalid" );
                expect( result.results[ 1 ].success ).toBeFalse();
                expect( result.results[ 1 ].statusCode ).toBe( 0 );
                expect( result.results[ 2 ].subscriber ).toBe( "person@example.com" );
                expect( result.results[ 2 ].success ).toBeTrue();
                expect( result.results[ 2 ].statusCode ).toBeGTE( 200 );
                expect( result.results[ 2 ].statusCode ).toBeLT( 300 );
                expect( variables.hyper ).toHaveSentCount( 1 );
                expect(
                    result.results.filter( function( item ) {
                        return !item.success;
                    } )[ 1 ].error
                ).toInclude( "Invalid subscriber email" );
            } );

            it( "returns mixed success and failure details for cancel invalid subscribers", function() {
                var result = variables.client.cancel(
                    listKey = "myList",
                    subscribers = [ "person@example.com", "not-an-email" ]
                );

                expect( result.total ).toBe( 2 );
                expect( result.success ).toBeFalse();
                expect( result.succeeded ).toBe( 1 );
                expect( result.failed ).toBe( 1 );
                expect( result.results ).toHaveLength( 2 );
                expect( result.results[ 1 ].subscriber ).toBe( "not-an-email" );
                expect( result.results[ 1 ].exceptionType ).toBe( "InvalidSubscriber" );
                expect( result.results[ 2 ].subscriber ).toBe( "person@example.com" );
                expect( result.results[ 2 ].success ).toBeTrue();
                expect( variables.hyper ).toHaveSentCount( 1 );
            } );

            it( "returns only preflight failures for cancel when all subscribers are invalid", function() {
                var result = variables.client.cancel(
                    listKey = "myList",
                    subscribers = [ "not-an-email-1", "not-an-email-2" ]
                );

                expect( result.total ).toBe( 2 );
                expect( result.success ).toBeFalse();
                expect( result.succeeded ).toBe( 0 );
                expect( result.failed ).toBe( 2 );
                expect( result.results ).toHaveLength( 2 );
                expect( result.results[ 1 ].exceptionType ).toBe( "InvalidSubscriber" );
                expect( result.results[ 2 ].exceptionType ).toBe( "InvalidSubscriber" );
                expect( variables.hyper ).toHaveSentNothing();
            } );

            it( "returns only preflight failures when all subscribers are invalid and sends no requests", function() {
                var result = variables.client.create(
                    listKey = "myList",
                    subscribers = [ "invalid-one", "invalid-two" ]
                );

                expect( result.total ).toBe( 2 );
                expect( result.success ).toBeFalse();
                expect( result.succeeded ).toBe( 0 );
                expect( result.failed ).toBe( 2 );
                expect( result.results ).toHaveLength( 2 );
                expect( result.results[ 1 ].exceptionType ).toBe( "InvalidSubscriber" );
                expect( result.results[ 2 ].exceptionType ).toBe( "InvalidSubscriber" );
                expect( variables.hyper ).toHaveSentNothing();
            } );

            it( "marks operation result as failed when Cordial returns a non-2xx response", function() {
                variables.hyper
                    .fake( {
                        "/v2/contacts": function( newFakeResponse, req ) {
                            return newFakeResponse( 429, "Too Many Requests", "{}" );
                        }
                    } )
                    .preventStrayRequests();

                var result = variables.client.create( listKey = "myList", subscribers = [ "person@example.com" ] );

                expect( result.total ).toBe( 1 );
                expect( result.success ).toBeFalse();
                expect( result.succeeded ).toBe( 0 );
                expect( result.failed ).toBe( 1 );
                expect( result.results[ 1 ].subscriber ).toBe( "person@example.com" );
                expect( result.results[ 1 ].success ).toBeFalse();
                expect( result.results[ 1 ].statusCode ).toBe( 429 );
            } );

            it( "marks cancel results as failed when Cordial returns non-2xx", function() {
                variables.hyper
                    .fake( {
                        "/v2/contacts/email:*": function( newFakeResponse, req ) {
                            return newFakeResponse( 503, "Service Unavailable", "{}" );
                        }
                    } )
                    .preventStrayRequests();

                var result = variables.client.cancel( listKey = "myList", subscribers = [ "person@example.com" ] );

                expect( result.total ).toBe( 1 );
                expect( result.success ).toBeFalse();
                expect( result.succeeded ).toBe( 0 );
                expect( result.failed ).toBe( 1 );
                expect( result.results[ 1 ].subscriber ).toBe( "person@example.com" );
                expect( result.results[ 1 ].success ).toBeFalse();
                expect( result.results[ 1 ].statusCode ).toBe( 503 );
            } );

            it( "handles async future failures and returns mixed results", function() {
                variables.hyper
                    .fake( {
                        "/v2/contacts": function( newFakeResponse, req ) {
                            if ( req.getBody().channels.email.address == "explode@example.com" ) {
                                throw( type = "AsyncFutureBoom", message = "Boom from fake response callback" );
                            }
                            return newFakeResponse( 201, "Created", "{}" );
                        }
                    } )
                    .preventStrayRequests();

                var result = variables.client.create(
                    listKey = "myList",
                    subscribers = [ "explode@example.com", "ok@example.com" ],
                    maxConcurrency = 2
                );

                expect( result.total ).toBe( 2 );
                expect( result.success ).toBeFalse();
                expect( result.succeeded ).toBe( 1 );
                expect( result.failed ).toBe( 1 );
                var failedResults = result.results.filter( function( item ) {
                    return !item.success;
                } );
                expect( failedResults ).toHaveLength( 1 );
                expect( failedResults[ 1 ].subscriber ).toBe( "explode@example.com" );
                expect( failedResults[ 1 ].statusCode ).toBe( 0 );
                expect( failedResults[ 1 ].error ).toInclude( "Boom from fake response callback" );
            } );

            it( "falls back to sequential sends when async manager is missing", function() {
                variables.sequentialCallbackCount = 0;
                var fallbackHyper = buildCustomHyperWithMissingAsyncManager(
                    fakeConfiguration = {
                        "/v2/contacts": function( newFakeResponse, req ) {
                            variables.sequentialCallbackCount++;
                            if ( variables.sequentialCallbackCount == 1 ) {
                                throw( type = "SequentialBoom", message = "Boom from sequential send" );
                            }
                            return newFakeResponse( 201, "Created", "{}" );
                        }
                    }
                );

                variables.client.setHyperClient( fallbackHyper );

                var result = variables.client.create(
                    listKey = "myList",
                    subscribers = [ "explode@example.com", "ok@example.com" ],
                    maxConcurrency = 0
                );

                expect( result.total ).toBe( 2 );
                expect( result.success ).toBeFalse();
                expect( result.succeeded ).toBe( 1 );
                expect( result.failed ).toBe( 1 );
                expect( variables.client.getHyperClient() ).toHaveSentCount( 1 );
                expect(
                    result.results
                        .filter( function( item ) {
                            return !item.success;
                        } )
                        .len()
                ).toBe( 1 );
            } );

            it( "records sendAsync setup errors when async manager throws non-missing errors", function() {
                var erroringAsyncManager = {
                    newFuture: function() {
                        throw( type = "AsyncManagerBoom", message = "No futures available" );
                    }
                };

                var fallbackHyper = buildCustomHyper(
                    asyncManager = erroringAsyncManager,
                    fakeConfiguration = {
                        "/v2/contacts/email:*": function( newFakeResponse, req ) {
                            return newFakeResponse( 200, "OK", "{}" );
                        }
                    }
                );

                variables.client.setHyperClient( fallbackHyper );

                var result = variables.client.cancel(
                    listKey = "myList",
                    subscribers = [ "one@example.com", "two@example.com" ]
                );

                expect( result.total ).toBe( 2 );
                expect( result.success ).toBeFalse();
                expect( result.succeeded ).toBe( 0 );
                expect( result.failed ).toBe( 2 );
                expect(
                    result.results
                        .filter( function( item ) {
                            return item.exceptionType == "AsyncManagerBoom";
                        } )
                        .len()
                ).toBe( 2 );
            } );

            it( "does not duplicate sends or results when async fallback triggers mid-batch", function() {
                variables.flakyAsyncCount = 0;
                var flakyAsyncManager = {
                    newFuture: function( task ) {
                        variables.flakyAsyncCount++;

                        if ( variables.flakyAsyncCount == 1 ) {
                            return {
                                get: function() {
                                    return task();
                                }
                            };
                        }

                        throw( type = "MissingAsyncManager", message = "Async manager unavailable after first future" );
                    }
                };

                var fallbackHyper = buildCustomHyper(
                    asyncManager = flakyAsyncManager,
                    fakeConfiguration = {
                        "/v2/contacts": function( newFakeResponse, req ) {
                            return newFakeResponse( 201, "Created", "{}" );
                        }
                    }
                );

                variables.client.setHyperClient( fallbackHyper );

                var result = variables.client.create(
                    listKey = "myList",
                    subscribers = [ "one@example.com", "two@example.com", "three@example.com" ],
                    maxConcurrency = 3
                );

                expect( result.total ).toBe( 3 );
                expect( result.success ).toBeTrue();
                expect( result.succeeded ).toBe( 3 );
                expect( result.failed ).toBe( 0 );
                expect( result.results ).toHaveLength( 3 );
                expect( variables.client.getHyperClient() ).toHaveSentCount( 3 );
                expect(
                    result.results
                        .filter( function( item ) {
                            return item.subscriber == "one@example.com";
                        } )
                        .len()
                ).toBe( 1 );
                expect(
                    result.results
                        .filter( function( item ) {
                            return item.subscriber == "two@example.com";
                        } )
                        .len()
                ).toBe( 1 );
                expect(
                    result.results
                        .filter( function( item ) {
                            return item.subscriber == "three@example.com";
                        } )
                        .len()
                ).toBe( 1 );
            } );

            it( "uses configured maxConcurrency when maxConcurrency argument is <= 0", function() {
                variables.client.setMaxConcurrency( 1 );

                var result = variables.client.create(
                    listKey = "myList",
                    subscribers = [ "person1@example.com", "person2@example.com" ],
                    maxConcurrency = 0
                );

                expect( result.total ).toBe( 2 );
                expect( result.success ).toBeTrue();
                expect( result.succeeded ).toBe( 2 );
                expect( variables.hyper ).toHaveSentCount( 2 );
            } );
        } );
    }

    private any function buildCustomHyper( required any asyncManager, required struct fakeConfiguration ) {
        var defaults = new Hyper.models.HyperRequest().setAsyncManager( arguments.asyncManager );

        var customHyper = new Hyper.models.HyperBuilder( defaults = defaults );
        customHyper.fake( arguments.fakeConfiguration ).preventStrayRequests();

        return customHyper;
    }

    private any function buildCustomHyperWithMissingAsyncManager( required struct fakeConfiguration ) {
        var defaults = new Hyper.models.HyperRequest();

        var customHyper = new Hyper.models.HyperBuilder( defaults = defaults );
        customHyper.fake( arguments.fakeConfiguration ).preventStrayRequests();

        return customHyper;
    }

    private void function configureDefaultFakes() {
        variables.hyper
            .clearFakes()
            .fake( {
                "/v2/contacts": function( newFakeResponse, req ) {
                    return newFakeResponse( 201, "Created", "{}" );
                },
                "/v2/contacts/email:*": function( newFakeResponse, req ) {
                    return newFakeResponse( 200, "OK", "{}" );
                }
            } )
            .preventStrayRequests();
    }

}
