import Foundation

/// Bilingual annotations (English + 中文) for well-known metadata fields.
///
/// The dictionary is intentionally incomplete by design: only common,
/// well-understood fields carry an explanation. Unknown or vendor specific
/// keys return `nil` and are displayed "as-is" without any annotation,
/// per the product requirements.
///
/// Lookups use the *stripped* key — AVFoundation keys such as
/// `com.apple.quicktime.make` are normalized to `Make` by the extractors
/// before hitting this database.
public enum FieldDescriptions {

    /// Returns the bilingual explanation for a well-known field, or `nil`
    /// when the field is unknown (in which case the UI shows no annotation).
    ///
    /// Lookup is exact first, then case-insensitive, so both `CreationDate`
    /// (EXIF style) and `Creationdate` (QuickTime style) match.
    public static func note(forKey key: String) -> FieldNote? {
        if let exact = notes[key] { return exact }
        return caseInsensitiveIndex[key.lowercased()]
    }

    /// Precomputed case-insensitive index. Built by iterating the primary
    /// table in *sorted* key order, so spelling aliases that differ only in
    /// case (e.g. `SubSecTimeOriginal` / `SubsecTimeOriginal`) resolve
    /// deterministically — `Dictionary` iteration order is randomized per
    /// process and must not decide which alias wins.
    private static let caseInsensitiveIndex: [String: FieldNote] = {
        var index: [String: FieldNote] = [:]
        for key in notes.keys.sorted() {
            index[key.lowercased()] = notes[key]
        }
        return index
    }()

    // MARK: - The annotation database

    /// Convenience initializer for the table below.
    private static func n(_ en: String, _ zh: String) -> FieldNote {
        FieldNote(en: en, zh: zh)
    }

    private static let notes: [String: FieldNote] = [

        // ---------------------------------------------------------------
        // File system
        // ---------------------------------------------------------------
        "FileName": n("Name of the file.", "文件名。"),
        "FilePath": n("Full path of the file on disk.", "文件在磁盘上的完整路径。"),
        "FileSize": n("Size of the file.", "文件大小。"),
        "ContentType": n("Uniform Type Identifier (UTI); how macOS recognizes the file type.", "统一类型标识符（UTI），macOS 用来识别文件类型。"),
        "MIMEType": n("MIME type, commonly used to identify content over the network.", "MIME 类型，常用于网络传输时标识内容格式。"),
        "FileCreationDate": n("When the file was created.", "文件创建时间。"),
        "FileModificationDate": n("When the file content was last modified.", "文件内容最后一次修改时间。"),

        // ---------------------------------------------------------------
        // Generic image properties (ImageIO top level)
        // ---------------------------------------------------------------
        "ImageFormat": n("Image container/encoding format.", "图像容器/编码格式。"),
        "ImageCount": n("Number of frames; values above 1 usually mean an animation.", "文件包含的图像帧数，大于 1 通常是动图。"),
        "PixelWidth": n("Image width in pixels.", "图像宽度，单位：像素。"),
        "PixelHeight": n("Image height in pixels.", "图像高度，单位：像素。"),
        "DPIWidth": n("Horizontal print resolution in dots per inch.", "打印分辨率（水平），单位：点/英寸。"),
        "DPIHeight": n("Vertical print resolution in dots per inch.", "打印分辨率（垂直），单位：点/英寸。"),
        "ColorModel": n("Color model, e.g. RGB or CMYK.", "颜色模型，如 RGB、CMYK。"),
        "Depth": n("Bits per color channel.", "每个颜色通道的位深（bit）。"),
        "ProfileName": n("Embedded ICC color profile; determines color reproduction.", "内嵌的 ICC 颜色配置文件名称，决定色彩如何还原。"),
        "HasAlpha": n("Whether the image has a transparency channel.", "是否包含透明通道。"),
        "Orientation": n("Display orientation written by the camera; viewers rotate accordingly.", "图像显示方向；拍摄设备写入，查看器据此旋转画面。"),

        // ---------------------------------------------------------------
        // TIFF / IFD0
        // ---------------------------------------------------------------
        "Make": n("Device manufacturer.", "设备制造商。"),
        "Model": n("Device model.", "设备型号。"),
        "Software": n("Software (and version) that produced or modified the file.", "生成或修改该文件的软件及版本。"),
        "DateTime": n("When the file's metadata was last modified.", "文件元数据的修改时间。"),
        "XResolution": n("Horizontal resolution.", "水平分辨率。"),
        "YResolution": n("Vertical resolution.", "垂直分辨率。"),
        "ResolutionUnit": n("Unit of the resolution values (inch or cm).", "分辨率单位（英寸或厘米）。"),
        "Artist": n("Artist / author (photographer).", "艺术家/作者（拍摄者）。"),
        "Copyright": n("Copyright information.", "版权信息。"),
        "HostComputer": n("Computer or device that generated the file.", "生成文件的计算机/设备。"),
        "ImageDescription": n("Textual description of the image.", "图像的文字描述。"),

        // ---------------------------------------------------------------
        // EXIF
        // ---------------------------------------------------------------
        "ExposureTime": n("Exposure time (shutter speed) in seconds.", "曝光时间（快门速度），单位：秒。"),
        "FNumber": n("Aperture f-number; smaller means a wider aperture and more light.", "光圈值（F 值）；数值越小光圈越大、进光量越多。"),
        "ExposureProgram": n("The camera's exposure program mode.", "相机的曝光程序模式。"),
        "ISOSpeedRatings": n("ISO speed; higher is more light-sensitive but noisier.", "感光度（ISO）；数值越高对光越敏感，噪点也越多。"),
        "ExifVersion": n("Version of the EXIF standard.", "EXIF 标准版本号。"),
        "DateTimeOriginal": n("When the photo was originally taken.", "原始拍摄时间。"),
        "DateTimeDigitized": n("When the image was digitized (usually equals capture time).", "图像数字化时间（通常与拍摄时间相同）。"),
        "OffsetTime": n("Timezone offset of the modification time.", "修改时间对应的时区偏移。"),
        "OffsetTimeOriginal": n("Timezone offset of the capture time.", "拍摄时间对应的时区偏移。"),
        "OffsetTimeDigitized": n("Timezone offset of the digitization time.", "数字化时间对应的时区偏移。"),
        "ShutterSpeedValue": n("Shutter speed as an APEX value (already converted to seconds).", "快门速度，APEX 制式值（已换算为实际秒数）。"),
        "ApertureValue": n("Aperture as an APEX value (already converted to f-number).", "光圈，APEX 制式值（已换算为 F 值）。"),
        "MaxApertureValue": n("Maximum aperture of the lens, APEX scale.", "镜头最大光圈，APEX 制式值。"),
        "BrightnessValue": n("Scene brightness, APEX scale.", "画面亮度，APEX 制式值。"),
        "ExposureBiasValue": n("Exposure compensation in EV.", "曝光补偿，单位：EV。"),
        "MeteringMode": n("The camera's metering mode.", "相机的测光模式。"),
        "LightSource": n("Type of light source when shooting.", "拍摄时的光源类型。"),
        "Flash": n("Flash status, decoded from the EXIF bit mask.", "闪光灯工作状态（位掩码解码）。"),
        "FocalLength": n("Actual lens focal length in millimeters.", "镜头实际焦距，单位：毫米。"),
        "FocalLengthIn35mmFilmFormat": n("35mm full-frame equivalent focal length, for comparing field of view.", "等效 35mm 全画幅焦距，便于比较视角。"),
        "FocalLenIn35mmFilm": n("35mm full-frame equivalent focal length, for comparing field of view.", "等效 35mm 全画幅焦距，便于比较视角。"),
        "SubjectArea": n("Region of the frame occupied by the subject.", "被摄主体在画面中的区域。"),
        "SubjectDistanceRange": n("Distance range of the subject.", "被摄主体的距离范围。"),
        "SubSecTime": n("Sub-second fraction of the timestamp.", "秒以下的时间精度（小数秒）。"),
        "SubSecTimeOriginal": n("Sub-second fraction of the capture time.", "拍摄时间的小数秒部分。"),
        "SubSecTimeDigitized": n("Sub-second fraction of the digitization time.", "数字化时间的小数秒部分。"),
        "SubsecTimeOriginal": n("Sub-second fraction of the capture time.", "拍摄时间的小数秒部分。"),
        "SubsecTimeDigitized": n("Sub-second fraction of the digitization time.", "数字化时间的小数秒部分。"),
        "ColorSpace": n("Color space of the image.", "图像色彩空间。"),
        "ExifImageWidth": n("Image width as recorded in EXIF, in pixels.", "图像宽度（EXIF 记录值），单位：像素。"),
        "ExifImageHeight": n("Image height as recorded in EXIF, in pixels.", "图像高度（EXIF 记录值），单位：像素。"),
        "PixelXDimension": n("Image width as recorded in EXIF, in pixels.", "图像宽度（EXIF 记录值），单位：像素。"),
        "PixelYDimension": n("Image height as recorded in EXIF, in pixels.", "图像高度（EXIF 记录值），单位：像素。"),
        "SensingMethod": n("Type of image sensor.", "图像传感器类型。"),
        "SceneType": n("Scene type; usually “directly photographed”.", "场景类型；通常为“直接拍摄”。"),
        "SceneCaptureType": n("Scene mode used by the camera (standard/landscape/portrait/night).", "相机使用的场景模式（标准/风光/人像/夜景）。"),
        "ExposureMode": n("Exposure mode (auto/manual/auto bracket).", "曝光模式（自动/手动/包围曝光）。"),
        "WhiteBalance": n("White balance mode.", "白平衡模式。"),
        "DigitalZoomRatio": n("Digital zoom ratio; 1 means no digital zoom.", "数码变焦倍率；1 表示未使用。"),
        "GainControl": n("Gain processing applied to the image.", "图像增益处理。"),
        "Contrast": n("Contrast processing.", "对比度处理。"),
        "Saturation": n("Saturation processing.", "饱和度处理。"),
        "Sharpness": n("Sharpness processing.", "锐化处理。"),
        "CustomRendered": n("Whether custom in-camera image processing was applied.", "是否在相机内做了自定义图像处理。"),
        "LensInfo": n("Lens focal length and aperture range.", "镜头焦距与光圈范围信息。"),
        "LensMake": n("Lens manufacturer.", "镜头制造商。"),
        "LensModel": n("Lens model.", "镜头型号。"),
        "LensSpecification": n("Lens specification (focal length / aperture range).", "镜头规格（焦距/光圈范围）。"),
        "CompositeImage": n("Whether this is a multi-frame composite image (e.g. iPhone Deep Fusion).", "是否为多帧合成图像（如 iPhone 的 Deep Fusion）。"),
        "UserComment": n("Comment written by the user or device.", "用户或设备写入的注释。"),
        "MakerNote": n("Vendor-private data block (structure differs per brand).", "厂商私有数据块（不同品牌结构不同）。"),
        "FlashpixVersion": n("Version of the FlashPix format.", "FlashPix 格式版本。"),
        "YCbCrPositioning": n("Reference point of the color sampling.", "色彩采样位置基准。"),
        "ComponentsConfiguration": n("Configuration of the color components.", "颜色分量配置。"),
        "CompressedBitsPerPixel": n("Bits per pixel after compression.", "压缩后每像素比特数。"),
        "InteropIndex": n("Interoperability index.", "互操作性索引。"),

        // ---------------------------------------------------------------
        // GPS
        // ---------------------------------------------------------------
        "GPSLatitudeRef": n("Latitude hemisphere: N = north, S = south.", "纬度半球：N 北纬，S 南纬。"),
        "GPSLatitude": n("Latitude where the photo was taken.", "拍摄地纬度。"),
        "GPSLongitudeRef": n("Longitude hemisphere: E = east, W = west.", "经度半球：E 东经，W 西经。"),
        "GPSLongitude": n("Longitude where the photo was taken.", "拍摄地经度。"),
        "GPSAltitudeRef": n("Altitude reference (above/below sea level).", "海拔基准（海平面之上/之下）。"),
        "GPSAltitude": n("Altitude where the photo was taken, in meters.", "拍摄地海拔高度，单位：米。"),
        "GPSTimeStamp": n("UTC time of the GPS fix.", "GPS 定位的 UTC 时间。"),
        "GPSDateStamp": n("UTC date of the GPS fix.", "GPS 定位的 UTC 日期。"),
        "GPSImgDirection": n("Direction the lens was pointing, in degrees.", "拍摄时镜头朝向（方位角，度）。"),
        "GPSImgDirectionRef": n("Direction reference: T = true north, M = magnetic north.", "方位角基准：T 真北，M 磁北。"),
        "GPSDestBearing": n("Bearing to the destination, in degrees.", "目的地方位角（度）。"),
        "GPSDestBearingRef": n("Reference of the destination bearing.", "目的地方位角基准。"),
        "GPSSpeedRef": n("Speed unit: K = km/h, M = mph, N = knots.", "速度单位：K 公里/时，M 英里/时，N 节。"),
        "GPSSpeed": n("Movement speed when shooting.", "拍摄时移动速度。"),
        "GPSTrack": n("Direction of movement, in degrees.", "运动方向（方位角，度）。"),
        "GPSTrackRef": n("Reference of the movement direction.", "运动方向基准。"),
        "GPSHPositioningError": n("Horizontal positioning error in meters; smaller is more precise.", "水平定位误差，单位：米；越小越精确。"),
        "GPSDOP": n("GPS dilution of precision (DOP); smaller means better accuracy.", "GPS 精度因子（DOP），越小定位越准。"),
        "GPSMeasureMode": n("GPS measurement mode (2D/3D).", "GPS 测量模式（2D/3D）。"),
        "GPSSatellites": n("Satellites used for the fix.", "用于定位的卫星。"),
        "GPSMapDatum": n("Geodetic survey datum of the coordinates.", "GPS 坐标使用的测绘基准。"),

        // ---------------------------------------------------------------
        // IPTC (editorial metadata)
        // ---------------------------------------------------------------
        "Caption/Abstract": n("Caption text of the image.", "图片说明文字。"),
        "Keywords": n("List of keywords.", "关键词列表。"),
        "Credit": n("Credit / provider of the image.", "图片来源/供图方。"),
        "Source": n("Original source of the content.", "内容原始来源。"),
        "City": n("City where the photo was taken.", "拍摄地城市。"),
        "Country-PrimaryLocationName": n("Country where the photo was taken.", "拍摄地国家。"),
        "By-line": n("Author attribution.", "作者署名。"),
        "Headline": n("Headline.", "标题。"),
        "ObjectName": n("Object name.", "对象名称。"),

        // ---------------------------------------------------------------
        // AVFoundation - General (movie / audio container)
        // ---------------------------------------------------------------
        "Duration": n("Total duration of the media.", "媒体总时长。"),
        "OverallBitRate": n("Overall bit rate (file size ÷ duration); a measure of compression.", "整体码率（文件大小 ÷ 时长），衡量压缩程度。"),
        "IsPlayable": n("Whether the current system can decode and play it.", "当前系统是否可以解码播放。"),
        "IsExportable": n("Whether it can be transcoded and exported.", "是否可以被转码导出。"),
        "PreferredRate": n("Default playback rate (1 = normal speed).", "默认播放速率（1 = 原速）。"),
        "PreferredVolume": n("Default playback volume.", "默认音量。"),
        "Title": n("Title.", "标题。"),
        "Creator": n("Creator of the content.", "创作者。"),
        "Subject": n("Subject of the content.", "主题。"),
        "Description": n("Description of the content.", "描述。"),
        "Publisher": n("Publisher.", "发行方。"),
        "Contributor": n("Contributing creator.", "参与创作者。"),
        "Type": n("Content type.", "内容类型。"),
        "Format": n("Content format.", "内容格式。"),
        "Language": n("Language.", "语言。"),
        "Location": n("Where the content was recorded.", "拍摄位置。"),
        "Location.ISO6709": n("Recording location in ISO 6709 format (latitude/longitude/altitude).", "拍摄位置，ISO 6709 标准格式（纬度/经度/海拔）。"),
        "LocationISO6709": n("Recording location in ISO 6709 format (latitude/longitude/altitude).", "拍摄位置，ISO 6709 标准格式（纬度/经度/海拔）。"),
        "CreationDate": n("When the content was created (usually UTC).", "内容创建时间（通常为 UTC）。"),
        "ModificationDate": n("When the content was modified.", "内容修改时间。"),
        "ContentIdentifier": n("Unique content identifier (used e.g. for Live Photo pairing).", "内容唯一标识符（用于实况照片配对等）。"),
        "LocationAccuracyHorizontal": n("Horizontal location accuracy in meters.", "水平定位精度，单位：米。"),
        "FullFrameRatePlaybackIntent": n("Whether full-frame-rate playback is intended (high-fps video flag).", "是否应按完整帧率播放（高帧率视频标记）。"),
        "LivePhotoAuto": n("Live Photo auto-capture flag.", "实况照片自动捕捉标记。"),
        "LivePhotoVitalityScore": n("Live Photo “interestingness” score.", "实况照片“精彩程度”评分。"),
        "LivePhotoVitalityScoringVersion": n("Version of the Live Photo scoring algorithm.", "实况照片评分算法版本。"),
        "CameraLensIrisfnumber": n("Aperture f-number used for the recording.", "拍摄光圈值（F 值）。"),

        // ---------------------------------------------------------------
        // Tracks
        // ---------------------------------------------------------------
        "TrackID": n("Identifier of the track inside the container.", "轨道在容器内的编号。"),
        "MediaType": n("Track type: video (vide), audio (soun), etc.", "轨道类型：视频（video）、音频（soun）等。"),
        "IsEnabled": n("Whether the track is enabled by default during playback.", "播放时该轨道是否默认启用。"),
        "Codec": n("Encoding format (FourCC and name).", "编码格式（FourCC 及名称）。"),
        "NaturalSize": n("Natural display size (width × height in pixels).", "画面原始尺寸（宽 × 高，像素）。"),
        "Dimensions": n("Encoded dimensions (width × height in pixels).", "编码尺寸（宽 × 高，像素）。"),
        "NominalFrameRate": n("Nominal frame rate in frames per second.", "标称帧率，单位：帧/秒。"),
        "EstimatedDataRate": n("Estimated bit rate of this track.", "该轨道的估算码率。"),
        "Rotation": n("Rotation to apply during playback.", "播放时需要应用的旋转角度。"),
        "SampleRate": n("Audio sample rate in Hz.", "音频采样率，单位：Hz。"),
        "Channels": n("Number of audio channels.", "声道数。"),
        "BitsPerChannel": n("Bit depth per audio channel.", "每个声道的量化位深（bit）。"),
        "FormatID": n("Audio encoding format identifier.", "音频编码格式标识。"),
        "ColorPrimaries": n("Color primaries standard (e.g. BT.709, Display P3).", "色彩原色标准（如 BT.709、Display P3）。"),
        "TransferFunction": n("Color transfer function (e.g. BT.709, PQ, HLG).", "色彩传递函数（如 BT.709、PQ、HLG）。"),
        "YCbCrMatrix": n("Matrix used for YUV to RGB conversion.", "YUV 与 RGB 转换矩阵。"),
        "LanguageCode": n("Language code of the track.", "轨道语言代码。"),
        "ExtendedLanguageTag": n("Extended language tag (BCP 47).", "扩展语言标签（BCP 47）。"),

        // ---------------------------------------------------------------
        // ID3 / iTunes (audio)
        // ---------------------------------------------------------------
        "Album": n("Album name.", "专辑名称。"),
        "AlbumArtist": n("Album artist (differs from track artist on compilations).", "专辑艺术家（合辑时区别于单曲艺术家）。"),
        "Genre": n("Music genre.", "音乐流派。"),
        "TrackNumber": n("Track number within the album.", "在专辑中的音轨号。"),
        "DiscNumber": n("Disc number within a multi-disc album.", "在多碟专辑中的碟号。"),
        "Composer": n("Composer.", "作曲者。"),
        "Comment": n("Comment.", "注释。"),
        "Lyrics": n("Lyrics.", "歌词。"),
        "Year": n("Release year.", "发行年份。"),
        "BPM": n("Beats per minute.", "每分钟节拍数。"),
        "Compilation": n("Whether the track is part of a compilation.", "是否为合辑。"),
        "Artwork": n("Embedded cover artwork.", "内嵌封面图片。"),
        "Encoder": n("Encoding software.", "编码软件。"),
        "EncodedBy": n("Who encoded the file.", "编码者。"),
        "CopyrightNotice": n("Copyright notice.", "版权声明。")
    ]
}
