component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

    function beforeAll() {
        super.beforeAll();
        variables.cordialClient = getInstance( "Subscriptions@cordial-sdk" );
        variables.hyperClient = getInstance( "CordialHyperClient@cordial-sdk" );
    }


    function run() {
        describe( "Subscription Management", function() {
            it( "can create and cancel subscriptions for multiple subscribers", function() {
                if ( !hasIntegrationConfig() ) {
                    skip( "No integration configuration found. Set CORDIAL_SDK_API_KEY, CORDIAL_SDK_BASE_URL, CORDIAL_SDK_TEST_LIST_KEY, and CORDIAL_SDK_TEST_EMAILS environment variables to run this test." );
                    return;
                }

                var listKey = getSystemSetting( "CORDIAL_SDK_TEST_LIST_KEY", "" );
                var emails = getTestEmails();

                var subscribeResult = variables.cordialClient.create( listKey = listKey, subscribers = emails );

                expect( subscribeResult.total ).toBe( emails.len() );
                expect( subscribeResult.succeeded ).toBeGTE( 1 );
                expect( subscribeResult.results ).toHaveLength( emails.len() );
                expect( subscribeResult.succeeded + subscribeResult.failed ).toBe( subscribeResult.total );

                for ( var email in emails ) {
                    var contactRes = variables.hyperClient
                        .new()
                        .setMethod( "GET" )
                        .setUrl( "/v2/contacts/email:#urlEncodedFormat( email )#" )
                        .send();

                    if ( contactRes.getStatusCode() >= 200 && contactRes.getStatusCode() < 300 ) {
                        var contactData = contactRes.json();
                        if ( structKeyExists( contactData, listKey ) ) {
                            expect( contactData[ listKey ] ).toBeTrue();
                        }
                    }
                }

                var cancelResult = variables.cordialClient.cancel( listKey = listKey, subscribers = emails );

                expect( cancelResult.total ).toBe( emails.len() );
                expect( cancelResult.succeeded ).toBeGTE( 1 );
                expect( cancelResult.results ).toHaveLength( emails.len() );
                expect( cancelResult.succeeded + cancelResult.failed ).toBe( cancelResult.total );

                for ( var email in emails ) {
                    var contactRes = variables.hyperClient
                        .new()
                        .setMethod( "GET" )
                        .setUrl( "/v2/contacts/email:#urlEncodedFormat( email )#" )
                        .send();

                    if ( contactRes.getStatusCode() >= 200 && contactRes.getStatusCode() < 300 ) {
                        var contactData = contactRes.json();
                        if ( structKeyExists( contactData, listKey ) ) {
                            expect( contactData[ listKey ] ).toBeFalse();
                        }
                    }
                }
            } );

            it( "returns mixed success and failure details for blank subscribers", function() {
                if ( !hasIntegrationConfig() ) {
                    skip( "No integration configuration found. Set CORDIAL_SDK_API_KEY, CORDIAL_SDK_BASE_URL, CORDIAL_SDK_TEST_LIST_KEY, and CORDIAL_SDK_TEST_EMAILS environment variables to run this test." );
                    return;
                }

                var listKey = getSystemSetting( "CORDIAL_SDK_TEST_LIST_KEY", "" );
                var validEmail = getTestEmails()[ 1 ];

                var result = variables.cordialClient.create( listKey = listKey, subscribers = [ validEmail, "   " ] );

                expect( result.total ).toBe( 2 );
                expect( result.succeeded ).toBeGTE( 1 );
                expect( result.failed ).toBeGTE( 1 );
                expect( result.results ).toHaveLength( 2 );
                expect( result.success ).toBeFalse();
                expect(
                    result.results
                        .filter( function( item ) {
                            return !item.success;
                        } )
                        .len()
                ).toBeGTE( 1 );
            } );
        } );
    }

    private boolean function hasIntegrationConfig() {
        return len( getSystemSetting( "CORDIAL_SDK_API_KEY", "" ) )
        && len( getSystemSetting( "CORDIAL_SDK_BASE_URL", "" ) )
        && len( getSystemSetting( "CORDIAL_SDK_TEST_LIST_KEY", "" ) )
        && getTestEmails().len();
    }

    private array function getTestEmails() {
        var testEmails = getSystemSetting( "CORDIAL_SDK_TEST_EMAILS", "" );
        if ( !len( testEmails ) ) {
            return [];
        }

        return testEmails
            .listToArray( "," )
            .map( function( item ) {
                return trim( item );
            } )
            .filter( function( item ) {
                return len( item );
            } );
    }

}
