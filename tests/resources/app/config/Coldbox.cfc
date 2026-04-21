component {

    function configure(){
        coldbox = {
            appName                  : getSystemSetting( "APPNAME", "Your app name here" ),
            eventName                : "event",
            reinitPassword           : "",
            reinitKey                : "fwreinit",
            handlersIndexAutoReload  : true,
            defaultEvent             : "",
            requestStartHandler      : "Main.onRequestStart",
            requestEndHandler        : "",
            applicationStartHandler  : "Main.onAppInit",
            applicationEndHandler    : "",
            sessionStartHandler      : "",
            sessionEndHandler        : "",
            missingTemplateHandler   : "",
            applicationHelper        : "includes/helpers/ApplicationHelper.cfm",
            viewsHelper              : "",
            modulesExternalLocation  : [],
            viewsExternalLocation    : "",
            layoutsExternalLocation  : "",
            handlersExternalLocation : "",
            requestContextDecorator  : "",
            controllerDecorator      : "",
            invalidHTTPMethodHandler : "",
            exceptionHandler         : "main.onException",
            invalidEventHandler      : "",
            customErrorTemplate      : "",
            handlerCaching           : false,
            eventCaching             : false,
            viewCaching              : false,
            autoMapModels            : true,
            jsonPayloadToRC          : true
        };

        settings = {};

        modules = {
            include : [],
            exclude : []
        };

        logBox = {
            appenders : { coldboxTracer : { class : "coldbox.system.logging.appenders.ConsoleAppender" } },
            root      : { levelmax : "INFO", appenders : "*" },
            info      : [ "coldbox.system" ]
        };

        layoutSettings = { defaultLayout : "", defaultView : "" };

        interceptorSettings = { customInterceptionPoints : [] };

        interceptors = [];

        moduleSettings = {
            "cordial-sdk" : {
                apiKey : getSystemSetting( "CORDIAL_SDK_API_KEY", "" ),
                baseURL : getSystemSetting( "CORDIAL_SDK_BASE_URL", "" ),
                maxConcurrency : val( getSystemSetting( "CORDIAL_SDK_MAX_CONCURRENCY", "10" ) ),
                forceSubscribe : isBoolean( getSystemSetting( "CORDIAL_SDK_FORCE_SUBSCRIBE", "false" ) ) && (
                    getSystemSetting( "CORDIAL_SDK_FORCE_SUBSCRIBE", "false" ) == true
                    || lCase( getSystemSetting( "CORDIAL_SDK_FORCE_SUBSCRIBE", "false" ) ) == "true"
                )
            }
        };

        flash = {
            scope        : "session",
            properties   : {},
            inflateToRC  : true,
            inflateToPRC : false,
            autoPurge    : true,
            autoSave     : true
        };

        conventions = {
            handlersLocation : "handlers",
            viewsLocation    : "views",
            layoutsLocation  : "layouts",
            modelsLocation   : "models",
            eventAction      : "index"
        };
    }

    function development(){
        coldbox.customErrorTemplate = "/coldbox/system/exceptions/Whoops.cfm";
    }

}
