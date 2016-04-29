// Request.swift
//
// Copyright (c) 2016 Auth0 (http://auth0.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

#if DEBUG
    let ParameterPropertyKey = "com.auth0.parameter"
#endif

public struct Request<T, Error: ErrorType>: Requestable {
    public typealias Callback = Result<T, Error> -> ()

    let session: NSURLSession
    let url: NSURL
    let method: String
    let handle: (Response, Callback) -> ()
    let payload: [String: AnyObject]
    let headers: [String: String]

    init(session: NSURLSession, url: NSURL, method: String, handle: (Response, Callback) -> (), payload: [String: AnyObject] = [:], headers: [String: String] = [:]) {
        self.session = session
        self.url = url
        self.method = method
        self.handle = handle
        self.payload = payload
        self.headers = headers
    }

    var request: NSURLRequest {
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = method
        if !payload.isEmpty {
            request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(payload, options: [])
            #if DEBUG
            NSURLProtocol.setProperty(payload, forKey: ParameterPropertyKey, inRequest: request)
            #endif
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { name, value in request.setValue(value, forHTTPHeaderField: name) }
        return request
    }

    public func start(callback: Callback) {
        let handler = self.handle
        session.dataTaskWithRequest(request) { handler(Response(data: $0, response: $1, error: $2), callback) }.resume()
    }

    public func concat<S>(request: Request<S, Error>) -> ConcatRequest<T, S, Error> {
        return ConcatRequest(first: self, second: request)
    }
    
}

public struct ConcatRequest<F, S, Error: ErrorType>: Requestable {
    let first: Request<F, Error>
    let second: Request<S, Error>

    func start(callback: Result<S, Error> -> ()) {
        let second = self.second
        first.start { result in
            switch result {
            case .Failure(let cause):
                callback(.Failure(error: cause))
            case .Success:
                second.start(callback)
            }
        }
    }
}
