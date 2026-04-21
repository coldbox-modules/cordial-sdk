component {

    this.name = "cordial-sdk";
    this.author = "Ortus Solutions";
    this.webUrl = "https://github.com/coldbox-modules/cordial-sdk";
    this.dependencies = [ "hyper" ];

    function configure() {
        settings = {
            apiKey: getSystemSetting( "CORDIAL_SDK_API_KEY", "" ),
            baseURL: getSystemSetting( "CORDIAL_SDK_BASE_URL", "" ),
            maxConcurrency: val( getSystemSetting( "CORDIAL_SDK_MAX_CONCURRENCY", "10" ) ),
            forceSubscribe: getSystemSetting( "CORDIAL_SDK_FORCE_SUBSCRIBE", "false" )
        };

        settings.forceSubscribe = isBoolean( settings.forceSubscribe ) && (
            settings.forceSubscribe == true || lCase( settings.forceSubscribe ) == "true"
        );
        settings.maxConcurrency = settings.maxConcurrency > 0 ? settings.maxConcurrency : 10;
    }

    function onLoad() {
        binder
            .map( "CordialHyperClient@cordial-sdk" )
            .to( "hyper.models.HyperBuilder" )
            .asSingleton()
            .initWith(
                username = settings.apiKey,
                password = "",
                baseURL = settings.baseURL,
                bodyFormat = "json",
                headers = { "Content-Type": "application/json", "Accept": "application/json" }
            );
    }

}
