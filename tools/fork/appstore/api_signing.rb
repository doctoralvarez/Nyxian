# api_signing.rb — fork doctoralvarez/Nyxian — version 1.0.0 (2026-11-23)
#
# App Store signing through the App Store Connect API, for the App Store (Xcode)
# workflow. Xcode's own automatic signing with an API key fails for this team
# ("Authentication failed ... bearer token" + "No profiles"), while the API
# itself creates certificates and profiles fine. So, for one upload:
#   setup   <work> <team> <bundle ids...>
#           creates an Apple Distribution certificate (new key + CSR), an App
#           Store profile for each bundle ID, writes <work>/sign/dist.p12 (+ .pass),
#           installs the profiles, writes <work>/sign/ExportOptions-manual.plist
#           and <work>/sign/cleanup.json
#   cleanup <work>
#           deletes those profiles and revokes that certificate (apps already
#           uploaded are not affected: Apple re-signs App Store builds)
# Needs ASC_KID, ASC_ISS and <work>/key/AuthKey_<ASC_KID>.p8. Writes notes to
# <work>/out/log.txt ("error:" lines show in Last Upload).

require "openssl"
require "json"
require "base64"
require "net/http"
require "fileutils"
require "securerandom"

WORK = ARGV[1]
LOG = File.join(WORK, "out", "log.txt")
def log(m) = File.open(LOG, "a") { |f| f.puts m }
def b64(s) = Base64.urlsafe_encode64(s, padding: false)

def jwt
  key = OpenSSL::PKey.read(File.read(File.join(WORK, "key", "AuthKey_#{ENV["ASC_KID"]}.p8")))
  now = Time.now.to_i
  input = b64({alg: "ES256", kid: ENV["ASC_KID"], typ: "JWT"}.to_json) + "." +
          b64({iss: ENV["ASC_ISS"], iat: now, exp: now + 900, aud: "appstoreconnect-v1"}.to_json)
  der = key.sign(OpenSSL::Digest::SHA256.new, input)
  input + "." + b64(OpenSSL::ASN1.decode(der).value.map { |i| i.value.to_s(2).rjust(32, "\0")[-32..] }.join)
end

def api(method, path, body = nil)
  uri = URI("https://api.appstoreconnect.apple.com" + path)
  klass = {get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete}[method]
  req = klass.new(uri)
  req["Authorization"] = "Bearer " + jwt
  req["Content-Type"] = "application/json"
  req.body = body.to_json if body
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 60) { |h| h.request(req) }
  data = (JSON.parse(res.body) rescue {})
  [res.code.to_i, data]
end

def errors(data) = (data["errors"] || []).map { |x| [x["code"], x["detail"] || x["title"]].compact.join(": ") }.join(" | ")

def setup(team, bundles)
  dir = File.join(WORK, "sign")
  FileUtils.mkdir_p(dir)
  cleanup = {"profiles" => [], "certificate" => nil}
  save = -> { File.write(File.join(dir, "cleanup.json"), cleanup.to_json) }

  # 1. certificate: new private key + CSR -> Apple Distribution
  rsa = OpenSSL::PKey::RSA.new(2048)
  csr = OpenSSL::X509::Request.new
  csr.subject = OpenSSL::X509::Name.parse("/CN=Nyxian upload #{Time.now.utc.strftime("%Y%m%d%H%M")}/C=US")
  csr.public_key = rsa.public_key
  csr.sign(rsa, OpenSSL::Digest::SHA256.new)
  code, cert = api(:post, "/v1/certificates", {data: {type: "certificates",
    attributes: {certificateType: "DISTRIBUTION", csrContent: csr.to_pem}}})
  unless code == 201
    log("error: Could not create an Apple Distribution certificate through the API (HTTP #{code}): #{errors(cert)}" +
        (errors(cert) =~ /maximum|limit|already/i ? " Revoke an unused Distribution certificate in developer.apple.com > Certificates and try again." : ""))
    exit 1
  end
  cleanup["certificate"] = cert["data"]["id"]; save.()
  x509 = OpenSSL::X509::Certificate.new(Base64.decode64(cert["data"]["attributes"]["certificateContent"]))
  pass = SecureRandom.hex(16)
  # 3DES / SHA1: the PKCS#12 format the macOS keychain imports everywhere
  p12 = OpenSSL::PKCS12.create(pass, "Nyxian upload", rsa, x509, nil, "PBE-SHA1-3DES", "PBE-SHA1-3DES", 2048, 2048)
  File.binwrite(File.join(dir, "dist.p12"), p12.to_der)
  File.write(File.join(dir, "dist.key"), rsa.to_pem)
  File.binwrite(File.join(dir, "dist.cer"), x509.to_der)
  File.write(File.join(dir, "dist.pass"), pass)
  log("API signing: Apple Distribution certificate created for this upload")

  # 2. an App Store profile for each bundle ID
  dirs = [File.expand_path("~/Library/MobileDevice/Provisioning Profiles"),
          File.expand_path("~/Library/Developer/Xcode/UserData/Provisioning Profiles")]
  dirs.each { |d| FileUtils.mkdir_p(d) }
  mapping = {}
  bundles.each do |bundle|
    code, found = api(:get, "/v1/bundleIds?filter[identifier]=#{bundle}&limit=20")
    bid = (found["data"] || []).find { |x| x["attributes"]["identifier"] == bundle && x["attributes"]["platform"] != "MAC_OS" }
    unless bid
      log("error: The App ID #{bundle} is not registered at Apple (HTTP #{code}). Run Preflight in Nyxian first.")
      exit 1
    end
    name = "Nyxian #{bundle} #{Time.now.utc.strftime("%Y%m%d%H%M%S")}"
    code, prof = api(:post, "/v1/profiles", {data: {type: "profiles",
      attributes: {name: name, profileType: "IOS_APP_STORE"},
      relationships: {bundleId: {data: {type: "bundleIds", id: bid["id"]}},
                      certificates: {data: [{type: "certificates", id: cleanup["certificate"]}]}}}})
    unless code == 201
      log("error: Could not create the App Store profile for #{bundle} (HTTP #{code}): #{errors(prof)}")
      exit 1
    end
    cleanup["profiles"] << prof["data"]["id"]; save.()
    uuid = prof["data"]["attributes"]["uuid"]
    content = Base64.decode64(prof["data"]["attributes"]["profileContent"])
    dirs.each { |d| File.binwrite(File.join(d, "#{uuid}.mobileprovision"), content) }
    mapping[bundle] = name
    log("API signing: App Store profile for #{bundle}")
  end

  # 3. export options for a manual signature with them
  opts = {"method" => "app-store-connect", "destination" => "upload", "signingStyle" => "manual",
          "signingCertificate" => "Apple Distribution", "provisioningProfiles" => mapping,
          "uploadSymbols" => true, "manageAppVersionAndBuildNumber" => false}
  opts["teamID"] = team unless team.to_s.empty?
  plist = +"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict>\n"
  opts.each do |k, v|
    plist << "<key>#{k}</key>"
    plist << case v
             when true, false then "<#{v}/>"
             when Hash then "<dict>" + v.map { |a, b| "<key>#{a}</key><string>#{b}</string>" }.join + "</dict>"
             else "<string>#{v}</string>"
             end
    plist << "\n"
  end
  plist << "</dict></plist>\n"
  File.write(File.join(dir, "ExportOptions-manual.plist"), plist)
end

def cleanup_all
  path = File.join(WORK, "sign", "cleanup.json")
  return unless File.exist?(path)
  c = JSON.parse(File.read(path))
  (c["profiles"] || []).each { |id| api(:delete, "/v1/profiles/#{id}") rescue nil }
  if c["certificate"]
    code, _ = (api(:delete, "/v1/certificates/#{c["certificate"]}") rescue [0, {}])
    log("API signing: temporary certificate and profiles removed (HTTP #{code})")
  end
end

case ARGV[0]
when "setup" then setup(ARGV[2], ARGV[3..] || [])
when "cleanup" then cleanup_all
else abort "usage: api_signing.rb setup <work> <team> <bundle ids...> | cleanup <work>"
end
