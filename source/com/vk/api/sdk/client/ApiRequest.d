module com.vk.api.sdk.client.ApiRequest;

import std.experimental.logger;
import vibe.data.json;
import std.json;

import com.vk.api.sdk.client.TransportClient;
import com.vk.api.sdk.exceptions.ApiException;
import com.vk.api.sdk.exceptions.ClientException;
import com.vk.api.sdk.objects.base.BaseError;

abstract class ApiRequest(T) {

    private TransportClient client;

    private string url;

    this(string url, TransportClient client) {
        this.client = client;
        this.url = url;
    }

    protected string getUrl() {
        return url;
    }

    protected TransportClient getClient() {
        return client;
    }

    T execute() {
        string textResponse = executeAsString();
        JSONValue json = parseJSON(textResponse);

        if (json["error"] != JSON_TYPE.NULL) {
            JSONValue errorElement = json["error"];
            BaseError error;
            try {
				error = deserializeJson!BaseError(errorElement);
            } catch (JsonSyntaxException e) {
                log("Invalid JSON: %s\n%s", textResponse, e.msg);
                throw new ClientException("Can't parse json response");
            }

            ApiException exception = ExceptionMapper.parseException(error);

            log("API error: ", exception.msg);
            throw exception;
        }

        JSONValue response = json;
        if (json["response"] != JSON_TYPE.NULL) {
            response = json["response"];
        }

        try {
            return deserializeJson!T(response);
        } catch (JsonSyntaxException e) {
            log("Invalid JSON: %s\n%s", textResponse, e.msg);
            throw new ClientException("Can't parse json response");
        }
    }

    string executeAsString() {
        ClientResponse response;
        try {
            response = client.post(url, getBody());
        } catch (IOException e) {
			log("Problems with request: %s\n%s", url, e.msg);
            throw new ClientException("I/O exception");
        }

        if (response.getStatusCode() != 200) {
            throw new ClientException("Internal API server error");
        }

        if (!response.getHeaders().containsKey("Content-Type")) {
            throw new ClientException("No content type header");
        }

        if (!response.getHeaders().get("Content-Type").contains("application/json")) {
            throw new ClientException("Invalid content type");
        }

        return response.getContent();
    }

    protected abstract string getBody();
}
