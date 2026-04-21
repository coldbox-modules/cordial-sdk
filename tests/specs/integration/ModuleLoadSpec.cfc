component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

    function run() {
        describe( "Module Load", function() {
            it( "can run integration specs with the module activated", function() {
                expect( getController().getModuleService().isModuleRegistered( "cordial-sdk" ) ).toBeTrue();
            } );

            it( "can resolve the Cordial client", function() {
                expect( getInstance( "Subscriptions@cordial-sdk" ) ).toBeComponent();
            } );
        } );
    }

}
