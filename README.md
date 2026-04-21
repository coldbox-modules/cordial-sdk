# WELCOME TO THE COLDBOX CORDIAL SDK

This module is a CFML SDK to interact with the Cordial Contact Management APIs.

## LICENSE

Apache License, Version 2.0.

## IMPORTANT LINKS

* https://github.com/coldbox-modules/cordial-sdk
* https://support.cordial.com/hc/en-us/sections/200533927-Contact-management-APIs

## SYSTEM REQUIREMENTS

* Lucee 5+
* Adobe ColdFusion 2018+
* ColdBox 8+

## Setup

Configure your Cordial credentials in the `config/ColdBox.cfc` file.

```cfc
moduleSettings = {
    "cordial-sdk" = {
        apiKey = getSystemSetting( "CORDIAL_SDK_API_KEY", "" ),
        baseURL = getSystemSetting( "CORDIAL_SDK_BASE_URL", "" ),
        maxConcurrency = 10,
        forceSubscribe = false
    }
};
```

### Settings

| Name | Type | Required? | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `apiKey` | String | `true` | `""` | Cordial API key. Can come from `CORDIAL_SDK_API_KEY` or ColdBox module overrides. |
| `baseURL` | String | `true` | `""` | Cordial account API base URL (for example, `https://<your-account-host>`). |
| `maxConcurrency` | Numeric | `false` | `10` | Maximum per-batch request concurrency. Values `<= 0` fall back to configured module default. |
| `forceSubscribe` | Boolean | `false` | `false` | Default `forceSubscribe` behavior for `create(...)`. |

## Methods

Resolve the service with WireBox:

```cfc
var subscriptions = getInstance( "Subscriptions@cordial-sdk" );
```

#### create

Creates subscriptions for one list and many subscribers.

```cfc
var result = subscriptions.create(
    listKey = "myListKey",
    subscribers = [ "one@example.com", "two@example.com" ],
    forceSubscribe = true,
    maxConcurrency = 5
);
```

| Name | Type | Required? | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `listKey` | String | `true` | | The Cordial list key to set to `true`. |
| `subscribers` | Array<String> | `true` | | Email subscribers for this operation. |
| `forceSubscribe` | Boolean | `false` | module setting | When true, includes `forceSubscribe: true` in the request payload. |
| `maxConcurrency` | Numeric | `false` | module setting | Max async requests in each chunk. |

Behavior:

* Uses `POST /v2/contacts` per valid subscriber.
* Sets `channels.email.address` and `channels.email.subscribeStatus = "subscribed"`.
* Sets dynamic list membership key (`<listKey> = true`).
* Invalid email entries are reported as failures and do not generate HTTP requests.

#### cancel

Cancels subscriptions for one list and many subscribers.

```cfc
var result = subscriptions.cancel(
    listKey = "myListKey",
    subscribers = [ "one@example.com", "two@example.com" ],
    maxConcurrency = 5
);
```

| Name | Type | Required? | Default | Description |
| ---- | ---- | --------- | ------- | ----------- |
| `listKey` | String | `true` | | The Cordial list key to set to `false`. |
| `subscribers` | Array<String> | `true` | | Email subscribers for this operation. |
| `maxConcurrency` | Numeric | `false` | module setting | Max async requests in each chunk. |

Behavior:

* Uses `PUT /v2/contacts/email:{urlEncodedEmail}` per valid subscriber.
* Sets dynamic list membership key (`<listKey> = false`).
* Does not perform global channel unsubscribe.
* Invalid email entries are reported as failures and do not generate HTTP requests.

## Return Contract

Both methods return an aggregate result struct:

```cfc
{
    success   : true|false,
    total     : numeric,
    succeeded : numeric,
    failed    : numeric,
    results   : [
        {
            subscriber    : "email@example.com",
            success       : true|false,
            statusCode    : numeric,
            response      : HyperResponse|null,
            error         : "",
            exceptionType : ""
        }
    ]
}
```

Notes:

* `success` is true only when `failed == 0`.
* `total` is the count of input subscribers.
* `results` includes preflight validation failures and HTTP operation outcomes.

## Hyper Integration

The Cordial SDK uses the Hyper HTTP Client under the hood.

In `ModuleConfig.cfc` the Hyper client is preconfigured with:

* Basic auth (`username = apiKey`, `password = ""`)
* Base URL from module settings
* JSON request/response headers

```cfc
binder
    .map( "CordialHyperClient@cordial-sdk" )
    .to( "hyper.models.HyperBuilder" )
    .asSingleton()
    .initWith(
        username = settings.apiKey,
        password = "",
        baseURL = settings.baseURL,
        bodyFormat = "json",
        headers = {
            "Content-Type" : "application/json",
            "Accept" : "application/json"
        }
    );
```

Because of this setup, each method only needs to provide endpoint and payload.

## Testing

### Unit Tests

Unit tests use Hyper fake support and TestBox matchers.

```bash
box server start --background --noSaveSettings --noOpenBrowser
# server stays running
```

Then run TestBox against `/tests/runner.cfm`.

### Integration Tests

Integration tests are live-first and skip when required env vars are missing:

* `CORDIAL_SDK_API_KEY`
* `CORDIAL_SDK_BASE_URL`
* `CORDIAL_SDK_TEST_LIST_KEY`
* `CORDIAL_SDK_TEST_EMAILS` (comma-separated)

These tests validate list membership changes against real Cordial contact records.
