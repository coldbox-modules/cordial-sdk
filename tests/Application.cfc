/**
 * Copyright Since 2005 Ortus Solutions, Corp
 * www.coldbox.org | www.luismajano.com | www.ortussolutions.com | www.gocontentbox.org
 **************************************************************************************
 */
component {

    this.name = "A TestBox Runner Suite " & hash( getCurrentTemplatePath() );
    this.sessionManagement = true;
    this.whiteSpaceManagement = "smart";

    testsPath = getDirectoryFromPath( getCurrentTemplatePath() );
    this.mappings[ "/tests" ] = testsPath;
    rootPath = reReplaceNoCase( this.mappings[ "/tests" ], "tests(\\|/)", "" );
    this.mappings[ "/root" ] = rootPath;
    this.mappings[ "/cordial-sdk" ] = rootPath;
    this.mappings[ "/hyper" ] = rootPath & "modules/hyper";
    this.mappings[ "/testingModuleRoot" ] = listDeleteAt( rootPath, listLen( rootPath, "\/" ), "\/" );
    this.mappings[ "/app" ] = testsPath & "resources/app";
    this.mappings[ "/coldbox" ] = testsPath & "resources/app/coldbox";
    this.mappings[ "/testbox" ] = rootPath & "testbox";

    public boolean function onRequestStart( String targetPage ) {
        structDelete( application, "cbController" );
        structDelete( application, "wirebox" );
        return true;
    }

}
