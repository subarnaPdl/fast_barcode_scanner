struct PreviewConfiguration {
  let previewWidth: Int32
  let previewHeight: Int32
  let analysisWidth: Int32
  let analysisHeight: Int32

  var dict: [String: Any] {
    [
      "preview_size": [previewWidth, previewHeight],
      "analysis_size": [analysisWidth, analysisHeight],
    ]
  }
}
