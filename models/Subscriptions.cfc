/**
 * Interact with the Cordial API.
 */
component singleton accessors="true" {

    property name="apiKey" inject="box:setting:apiKey@cordial-sdk";
    property name="maxConcurrency" inject="box:setting:maxConcurrency@cordial-sdk";
    property name="forceSubscribe" inject="box:setting:forceSubscribe@cordial-sdk";
    property name="hyperClient" inject="CordialHyperClient@cordial-sdk";

    /**
     * Create subscriptions for one list and many subscribers.
     */
    function create(
        required string listKey,
        required array subscribers,
        boolean forceSubscribe = variables.forceSubscribe,
        numeric maxConcurrency = variables.maxConcurrency
    ) {
        validateListKey( arguments.listKey );
        validateSubscribersArray( arguments.subscribers );

        var normalized = normalizeSubscribers( arguments.subscribers );
        var result = newAggregateResult( normalized.totalRequested );

        arrayAppend( result.results, normalized.preflightFailures, true );

        if ( !normalized.validEmails.len() ) {
            finalizeResult( result );
            return result;
        }

        var targetListKey = arguments.listKey;
        var shouldForceSubscribe = arguments.forceSubscribe;
        var operationResults = executeInParallel(
            emails = normalized.validEmails,
            concurrencyLimit = normalizeConcurrency( arguments.maxConcurrency ),
            callback = function( required string subscriberEmail ) {
                var payload = buildSubscribePayload(
                    listKey = targetListKey,
                    subscriberEmail = subscriberEmail,
                    shouldForceSubscribe = shouldForceSubscribe
                );

                return hyperClient
                    .new()
                    .setMethod( "POST" )
                    .setUrl( "/v2/contacts" )
                    .setBody( payload );
            }
        );

        arrayAppend( result.results, operationResults, true );
        finalizeResult( result );

        return result;
    }

    /**
     * Cancel subscriptions for one list and many subscribers.
     */
    function cancel(
        required string listKey,
        required array subscribers,
        numeric maxConcurrency = variables.maxConcurrency
    ) {
        validateListKey( arguments.listKey );
        validateSubscribersArray( arguments.subscribers );

        var normalized = normalizeSubscribers( arguments.subscribers );
        var result = newAggregateResult( normalized.totalRequested );

        arrayAppend( result.results, normalized.preflightFailures, true );

        if ( !normalized.validEmails.len() ) {
            finalizeResult( result );
            return result;
        }

        var targetListKey = arguments.listKey;
        var operationResults = executeInParallel(
            emails = normalized.validEmails,
            concurrencyLimit = normalizeConcurrency( arguments.maxConcurrency ),
            callback = function( required string subscriberEmail ) {
                var payload = {};
                payload[ targetListKey ] = false;

                return hyperClient
                    .new()
                    .setMethod( "PUT" )
                    .setUrl( "/v2/contacts/email:#urlEncodedFormat( subscriberEmail )#" )
                    .setBody( payload );
            }
        );

        arrayAppend( result.results, operationResults, true );
        finalizeResult( result );

        return result;
    }

    /**
     * Unsubscribe many subscribers from the email channel.
     */
    function unsubscribeAll( required array subscribers, numeric concurrencyLimit = variables.maxConcurrency ) {
        validateSubscribersArray( arguments.subscribers );

        var normalized = normalizeSubscribers( arguments.subscribers );
        var result = newAggregateResult( normalized.totalRequested );

        arrayAppend( result.results, normalized.preflightFailures, true );

        if ( !normalized.validEmails.len() ) {
            finalizeResult( result );
            return result;
        }

        var operationResults = executeInParallel(
            emails = normalized.validEmails,
            concurrencyLimit = normalizeConcurrency( arguments.concurrencyLimit ),
            callback = function( required string subscriberEmail ) {
                return hyperClient
                    .new()
                    .setMethod( "PUT" )
                    .setUrl( "/v2/contacts/email:#urlEncodedFormat( subscriberEmail )#/unsubscribe/email" );
            }
        );

        arrayAppend( result.results, operationResults, true );
        finalizeResult( result );

        return result;
    }

    /**
     * Resubscribe many subscribers to the email channel.
     */
    function resubscribe( required array subscribers, numeric concurrencyLimit = variables.maxConcurrency ) {
        validateSubscribersArray( arguments.subscribers );

        var normalized = normalizeSubscribers( arguments.subscribers );
        var result = newAggregateResult( normalized.totalRequested );

        arrayAppend( result.results, normalized.preflightFailures, true );

        if ( !normalized.validEmails.len() ) {
            finalizeResult( result );
            return result;
        }

        var operationResults = executeInParallel(
            emails = normalized.validEmails,
            concurrencyLimit = normalizeConcurrency( arguments.concurrencyLimit ),
            callback = function( required string subscriberEmail ) {
                return hyperClient
                    .new()
                    .setMethod( "PUT" )
                    .setUrl( "/v2/contacts/email:#urlEncodedFormat( subscriberEmail )#" )
                    .setBody( buildResubscribePayload() );
            }
        );

        arrayAppend( result.results, operationResults, true );
        finalizeResult( result );

        return result;
    }

    private struct function buildSubscribePayload(
        required string listKey,
        required string subscriberEmail,
        required boolean shouldForceSubscribe
    ) {
        var payload = {
            "channels": { "email": { "address": arguments.subscriberEmail, "subscribeStatus": "subscribed" } }
        };

        payload[ arguments.listKey ] = true;

        if ( arguments.shouldForceSubscribe ) {
            payload.forceSubscribe = true;
        }

        return payload;
    }

    private struct function buildResubscribePayload() {
        return { "forceSubscribe": true, "channels": { "email": { "subscribeStatus": "subscribed" } } };
    }

    private array function executeInParallel(
        required array emails,
        required numeric concurrencyLimit,
        required any callback
    ) {
        var allResults = [];
        var batches = chunkArray( arguments.emails, arguments.concurrencyLimit );

        for ( var batch in batches ) {
            var asyncQueue = [];
            var asyncSupported = true;
            var fallbackStartIndex = 0;

            for ( var i = 1; i <= batch.len(); i++ ) {
                var subscriberEmail = batch[ i ];
                var req = callback( subscriberEmail );

                try {
                    arrayAppend( asyncQueue, { subscriberEmail: subscriberEmail, future: req.sendAsync() } );
                } catch ( any e ) {
                    if (
                        e.type == "MissingAsyncManager"
                        || findNoCase( "No asyncManager set!", e.message )
                    ) {
                        asyncSupported = false;
                        fallbackStartIndex = i;
                        break;
                    }

                    arrayAppend(
                        allResults,
                        buildErrorResult(
                            subscriberEmail = subscriberEmail,
                            errorMessage = e.message,
                            exceptionType = e.type
                        )
                    );
                }
            }

            if ( asyncSupported ) {
                for ( var pending in asyncQueue ) {
                    arrayAppend( allResults, resolveFutureResult( pending.subscriberEmail, pending.future ) );
                }
                continue;
            }

            // Resolve any already-queued async requests first so they are not re-sent in fallback mode.
            for ( var pending in asyncQueue ) {
                arrayAppend( allResults, resolveFutureResult( pending.subscriberEmail, pending.future ) );
            }

            // Only process the remaining unqueued emails sequentially.
            for ( var i = fallbackStartIndex; i <= batch.len(); i++ ) {
                var subscriberEmail = batch[ i ];
                var req = callback( subscriberEmail );
                arrayAppend( allResults, sendSequential( subscriberEmail, req ) );
            }
        }

        return allResults;
    }

    private struct function resolveFutureResult( required string subscriberEmail, required any future ) {
        try {
            var response = arguments.future.get();
            return buildResponseResult( arguments.subscriberEmail, response );
        } catch ( any e ) {
            return buildErrorResult(
                subscriberEmail = arguments.subscriberEmail,
                errorMessage = e.message,
                exceptionType = e.type
            );
        }
    }

    private struct function sendSequential( required string subscriberEmail, required any req ) {
        try {
            return buildResponseResult( arguments.subscriberEmail, req.send() );
        } catch ( any e ) {
            return buildErrorResult(
                subscriberEmail = arguments.subscriberEmail,
                errorMessage = e.message,
                exceptionType = e.type
            );
        }
    }

    private struct function buildResponseResult( required string subscriberEmail, required any response ) {
        var memento = arguments.response.getMemento();
        memento[ "request" ] = arguments.response
            .getRequest()
            .getMemento(
                excludes = [
                    "authType",
                    "clientCert",
                    "clientCertPassword",
                    "domain",
                    "headers",
                    "password",
                    "username",
                    "workstation"
                ]
            );
        return {
            "subscriber": arguments.subscriberEmail,
            "success": arguments.response.isSuccess(),
            "statusCode": arguments.response.getStatusCode(),
            "response": memento,
            "error": arguments.response.getStatusText(),
            "exceptionType": ""
        };
    }

    private struct function buildErrorResult(
        required string subscriberEmail,
        required string errorMessage,
        string exceptionType = ""
    ) {
        return {
            "subscriber": arguments.subscriberEmail,
            "success": false,
            "statusCode": 0,
            "response": javacast( "null", 0 ),
            "error": arguments.errorMessage,
            "exceptionType": arguments.exceptionType
        };
    }

    private struct function normalizeSubscribers( required array subscribers ) {
        var validEmails = [];
        var preflightFailures = [];

        for ( var subscriber in arguments.subscribers ) {
            var subscriberEmail = trim( toString( subscriber ) );

            if ( !isValidEmail( subscriberEmail ) ) {
                arrayAppend(
                    preflightFailures,
                    buildErrorResult(
                        subscriberEmail = subscriberEmail,
                        errorMessage = "Subscriber email cannot be blank.",
                        exceptionType = "InvalidSubscriber"
                    )
                );
                continue;
            }

            arrayAppend( validEmails, subscriberEmail );
        }

        return {
            "validEmails": validEmails,
            "preflightFailures": preflightFailures,
            "totalRequested": arguments.subscribers.len()
        };
    }

    private boolean function isValidEmail( required string subscriberEmail ) {
        // Intentionally avoid format validation; Cordial should decide what it accepts.
        return len( arguments.subscriberEmail );
    }

    private numeric function normalizeConcurrency( required numeric value ) {
        return arguments.value > 0 ? int( arguments.value ) : variables.maxConcurrency;
    }

    private array function chunkArray( required array values, required numeric size ) {
        var chunked = [];

        for ( var i = 1; i <= arguments.values.len(); i += arguments.size ) {
            var stop = min( i + arguments.size - 1, arguments.values.len() );
            arrayAppend( chunked, arguments.values.slice( i, stop - i + 1 ) );
        }

        return chunked;
    }

    private struct function newAggregateResult( required numeric total ) {
        return {
            "success": false,
            "total": arguments.total,
            "succeeded": 0,
            "failed": 0,
            "results": []
        };
    }

    private void function finalizeResult( required struct aggregate ) {
        for ( var item in arguments.aggregate.results ) {
            item.success = normalizeSuccessFlag( item.success );

            if ( item.success ) {
                arguments.aggregate.succeeded++;
            } else {
                arguments.aggregate.failed++;
            }
        }

        arguments.aggregate.success = arguments.aggregate.failed == 0;
    }

    private boolean function normalizeSuccessFlag( required any value ) {
        if ( isBoolean( arguments.value ) ) {
            return javacast( "boolean", arguments.value );
        }

        return listFindNoCase( "true,yes,1", trim( toString( arguments.value ) ) ) > 0;
    }

    private void function validateListKey( required string listKey ) {
        if ( !len( trim( arguments.listKey ) ) ) {
            throw( type = "cordial-sdk.InvalidListKey", message = "The listKey argument is required." );
        }
    }

    private void function validateSubscribersArray( required array subscribers ) {
        if ( !arguments.subscribers.len() ) {
            throw( type = "cordial-sdk.InvalidSubscribers", message = "At least one subscriber is required." );
        }
    }

}
