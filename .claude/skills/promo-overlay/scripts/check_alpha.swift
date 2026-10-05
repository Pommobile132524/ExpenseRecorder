// Verify a mobile overlay .mov with AVFoundation (the decoder iPhone uses).
// usage: swift check_alpha.swift <file.mov> '{"clearZone":{"x":100,"y":820,"w":880,"h":330},"reveal":{"x":540,"y":1780,"at":3}}'
//   clearZone : a box that must stay fully transparent the whole time (where the user's clip shows)
//   reveal    : optional point that must be transparent before `at` seconds and opaque after (an element that pops in)
// Also scans the whole frame for "white-fringe risk": faint pixels whose colour would turn bright
// if an app treats colours as premultiplied (the CapCut export problem).
import AVFoundation

struct Box: Decodable { let x: Int; let y: Int; let w: Int; let h: Int }
struct Reveal: Decodable { let x: Int; let y: Int; let at: Double }
struct Opts: Decodable { let clearZone: Box; let reveal: Reveal? }
let opts = try! JSONDecoder().decode(Opts.self, from: (CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : #"{"clearZone":{"x":100,"y":820,"w":880,"h":330}}"#).data(using: .utf8)!)

let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
guard let track = asset.tracks(withMediaType: .video).first else { print("FAIL no video track"); exit(1) }
let fd = track.formatDescriptions[0] as! CMFormatDescription
let ext = CMFormatDescriptionGetExtensions(fd) as? [String: Any] ?? [:]
let fps = Double(track.nominalFrameRate), dur = CMTimeGetSeconds(asset.duration)
print(String(format: "file: %.0fx%.0f  %.0f fps  %.2f s", track.naturalSize.width, track.naturalSize.height, fps, dur))
print((ext["ContainsAlphaChannel"] as? Bool ?? false) ? "PASS alpha channel flag" : "FAIL no alpha flag")

let reader = try! AVAssetReader(asset: asset)
let out = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(out); reader.startReading()
let total = Int(fps * dur)
let sample = Set(stride(from: 0, to: total, by: max(1, Int(fps)))).union([total - 1])     // 1 frame per second
let fBefore = opts.reveal.map { Int(max(0, $0.at - 1) * fps) }, fAfter = opts.reveal.map { Int(min(dur - 0.1, $0.at + 2.5) * fps) }
var n = 0, clearMax = 0, worstClearAt = 0.0, before = -1, after = -1, risky = 0, faint = 0
while let sb = out.copyNextSampleBuffer() {
  defer { n += 1 }
  let want = sample.contains(n) || n == fBefore || n == fAfter
  guard want, let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
  CVPixelBufferLockBaseAddress(pb, .readOnly)
  let b = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self), bpr = CVPixelBufferGetBytesPerRow(pb)
  let W = CVPixelBufferGetWidth(pb), H = CVPixelBufferGetHeight(pb)
  func a(_ x: Int, _ y: Int) -> Int { Int(b[y*bpr + x*4 + 3]) }
  let z = opts.clearZone
  for y in stride(from: z.y, to: min(H, z.y + z.h), by: 6) { for x in stride(from: z.x, to: min(W, z.x + z.w), by: 6) {
    let v = a(x, y); if v > clearMax { clearMax = v; worstClearAt = Double(n) / fps } } }
  if let r = opts.reveal { if n == fBefore { before = a(r.x, r.y) }; if n == fAfter { after = a(r.x, r.y) } }
  if n == fAfter || (opts.reveal == nil && n == total / 2) {
    for y in stride(from: 0, to: H, by: 3) { for x in stride(from: 0, to: W, by: 3) {
      let i = y*bpr + x*4, al = Int(b[i+3]); if al > 0 && al < 40 { faint += 1
        let c = max(Int(b[i]), Int(b[i+1]), Int(b[i+2])); if c * 255 / al > 140 { risky += 1 } } } }
  }
  CVPixelBufferUnlockBaseAddress(pb, .readOnly)
}
print(clearMax <= 2 ? "PASS clip area stays transparent" : String(format: "FAIL clip area not transparent (alpha %d at %.1fs)", clearMax, worstClearAt))
if let r = opts.reveal, dur < r.at + 1.0 {
  print("SKIP reveal check — clip (\(dur)s) ends before the element is fully in (\(r.at)s)")
} else if let r = opts.reveal {
  print(before == 0 ? "PASS reveal point hidden before \(r.at)s" : "FAIL reveal point alpha before = \(before)")
  print(after > 200 ? "PASS reveal point visible after \(r.at)s" : "FAIL reveal point alpha after = \(after)")
}
let limit = max(3000, faint / 20)
print(risky < limit ? "PASS no white-fringe risk (\(risky) of \(faint) faint px; an unfixed file is ~90%)" : "FAIL white-fringe risk: \(risky) of \(faint) faint px")
print("frames decoded: \(n)")
