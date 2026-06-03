import Foundation
import CryptoKit

// Minimal App Store Connect API client.
// env: ASC_KEY_ID, ASC_ISSUER, ASC_KEY_PATH
// args: METHOD PATH [JSON_BODY]

func b64url(_ d: Data) -> String {
    d.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

let env = ProcessInfo.processInfo.environment
guard let keyId = env["ASC_KEY_ID"], let issuer = env["ASC_ISSUER"], let keyPath = env["ASC_KEY_PATH"] else {
    FileHandle.standardError.write("missing env\n".data(using: .utf8)!); exit(2)
}
let args = CommandLine.arguments
let method = args.count > 1 ? args[1] : "GET"
let path = args.count > 2 ? args[2] : "/v1/apps"
let body = args.count > 3 ? args[3] : nil

let pem = try String(contentsOfFile: keyPath, encoding: .utf8)
let key = try P256.Signing.PrivateKey(pemRepresentation: pem)

let now = Int(Date().timeIntervalSince1970)
let header = #"{"alg":"ES256","kid":"\#(keyId)","typ":"JWT"}"#
let payload = #"{"iss":"\#(issuer)","iat":\#(now),"exp":\#(now + 1000),"aud":"appstoreconnect-v1"}"#
let signingInput = b64url(Data(header.utf8)) + "." + b64url(Data(payload.utf8))
let sig = try key.signature(for: Data(signingInput.utf8))
let jwt = signingInput + "." + b64url(sig.rawRepresentation)

var req = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com\(path)")!)
req.httpMethod = method
req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
req.setValue("application/json", forHTTPHeaderField: "Content-Type")
if let body { req.httpBody = body.data(using: .utf8) }

let sem = DispatchSemaphore(value: 0)
URLSession.shared.dataTask(with: req) { data, resp, err in
    if let err { FileHandle.standardError.write("error: \(err)\n".data(using: .utf8)!) }
    if let http = resp as? HTTPURLResponse { print("HTTP \(http.statusCode)") }
    if let data, let s = String(data: data, encoding: .utf8) { print(s) }
    sem.signal()
}.resume()
sem.wait()
