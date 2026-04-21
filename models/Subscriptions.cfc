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
            maxConcurrency = normalizeConcurrency( arguments.maxConcurrency ),
            callback = function( required string email ) {
                var payload = buildSubscribePayload(
                    listKey = targetListKey,
                    email = email,
                    forceSubscribe = shouldForceSubscribe
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
            maxConcurrency = normalizeConcurrency( arguments.maxConcurrency ),
            callback = function( required string email ) {
                var payload = {};
                payload[ targetListKey ] = false;

                return hyperClient
                    .new()
                    .setMethod( "PUT" )
                    .setUrl( "/v2/contacts/email:#urlEncodedFormat( email )#" )
                    .setBody( payload );
            }
        );

        arrayAppend( result.results, operationResults, true );
        finalizeResult( result );

        return result;
    }

    private struct function buildSubscribePayload(
        required string listKey,
        required string email,
        required boolean forceSubscribe
    ) {
        var payload = { channels: { email: { address: arguments.email, subscribeStatus: "subscribed" } } };

        payload[ arguments.listKey ] = true;

        if ( arguments.forceSubscribe ) {
            payload.forceSubscribe = true;
        }

        return payload;
    }

    private array function executeInParallel(
        required array emails,
        required numeric maxConcurrency,
        required any callback
    ) {
        var allResults = [];
        var batches = chunkArray( arguments.emails, arguments.maxConcurrency );

        for ( var batch in batches ) {
            var asyncQueue = [];
            var asyncSupported = true;
            var fallbackStartIndex = 0;

            for ( var i = 1; i <= batch.len(); i++ ) {
                var email = batch[ i ];
                var req = callback( email );

                try {
                    arrayAppend( asyncQueue, { email: email, future: req.sendAsync() } );
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
                        buildErrorResult( email = email, errorMessage = e.message, exceptionType = e.type )
                    );
                }
            }

            if ( asyncSupported ) {
                for ( var pending in asyncQueue ) {
                    arrayAppend( allResults, resolveFutureResult( pending.email, pending.future ) );
                }
                continue;
            }

            // Resolve any already-queued async requests first so they are not re-sent in fallback mode.
            for ( var pending in asyncQueue ) {
                arrayAppend( allResults, resolveFutureResult( pending.email, pending.future ) );
            }

            // Only process the remaining unqueued emails sequentially.
            for ( var i = fallbackStartIndex; i <= batch.len(); i++ ) {
                var email = batch[ i ];
                var req = callback( email );
                arrayAppend( allResults, sendSequential( email, req ) );
            }
        }

        return allResults;
    }

    private struct function resolveFutureResult( required string email, required any future ) {
        try {
            var response = arguments.future.get();
            return buildResponseResult( arguments.email, response );
        } catch ( any e ) {
            return buildErrorResult( email = arguments.email, errorMessage = e.message, exceptionType = e.type );
        }
    }

    private struct function sendSequential( required string email, required any req ) {
        try {
            return buildResponseResult( arguments.email, req.send() );
        } catch ( any e ) {
            return buildErrorResult( email = arguments.email, errorMessage = e.message, exceptionType = e.type );
        }
    }

    private struct function buildResponseResult( required string email, required any response ) {
        var code = response.getStatusCode();

        return {
            subscriber: arguments.email,
            success: code >= 200 && code < 300,
            statusCode: code,
            response: response,
            error: "",
            exceptionType: ""
        };
    }

    private struct function buildErrorResult(
        required string email,
        required string errorMessage,
        string exceptionType = ""
    ) {
        return {
            subscriber: arguments.email,
            success: false,
            statusCode: 0,
            response: javacast( "null", 0 ),
            error: arguments.errorMessage,
            exceptionType: arguments.exceptionType
        };
    }

    private struct function normalizeSubscribers( required array subscribers ) {
        var validEmails = [];
        var preflightFailures = [];

        for ( var subscriber in arguments.subscribers ) {
            var email = trim( toString( subscriber ) );

            if ( !isValidEmail( email ) ) {
                arrayAppend(
                    preflightFailures,
                    buildErrorResult(
                        email = email,
                        errorMessage = "Invalid subscriber email [#email#].",
                        exceptionType = "InvalidSubscriber"
                    )
                );
                continue;
            }

            arrayAppend( validEmails, email );
        }

        return {
            validEmails: validEmails,
            preflightFailures: preflightFailures,
            totalRequested: arguments.subscribers.len()
        };
    }

    private boolean function isValidEmail( required string email ) {
        return len( arguments.email ) && isValid( "email", arguments.email );
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
            success: false,
            total: arguments.total,
            succeeded: 0,
            failed: 0,
            results: []
        };
    }

    private void function finalizeResult( required struct aggregate ) {
        for ( var item in arguments.aggregate.results ) {
            if ( item.success ) {
                arguments.aggregate.succeeded++;
            } else {
                arguments.aggregate.failed++;
            }
        }

        arguments.aggregate.success = arguments.aggregate.failed == 0;
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
