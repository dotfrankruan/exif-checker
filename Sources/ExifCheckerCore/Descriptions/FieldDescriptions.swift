import Foundation

/// Localized annotations (备注说明) for well-known metadata fields.
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

    /// Returns a Chinese explanation for a well-known field, or `nil` when
    /// the field is unknown (in which case the UI shows no annotation).
    public static func note(forKey key: String) -> String? {
        notes[key]
    }

    // MARK: - The annotation database

    private static let notes: [String: String] = [

        // ---------------------------------------------------------------
        // File system
        // ---------------------------------------------------------------
        "FileName": "文件名。",
        "FilePath": "文件在磁盘上的完整路径。",
        "FileSize": "文件大小。",
        "ContentType": "统一类型标识符（UTI），macOS 用来识别文件类型。",
        "MIMEType": "MIME 类型，常用于网络传输时标识内容格式。",
        "FileCreationDate": "文件创建时间。",
        "FileModificationDate": "文件内容最后一次修改时间。",

        // ---------------------------------------------------------------
        // Generic image properties (ImageIO top level)
        // ---------------------------------------------------------------
        "ImageFormat": "图像容器/编码格式。",
        "ImageCount": "文件包含的图像帧数，大于 1 通常是动图。",
        "PixelWidth": "图像宽度，单位：像素。",
        "PixelHeight": "图像高度，单位：像素。",
        "DPIWidth": "打印分辨率（水平），单位：点/英寸。",
        "DPIHeight": "打印分辨率（垂直），单位：点/英寸。",
        "ColorModel": "颜色模型，如 RGB、CMYK。",
        "Depth": "每个颜色通道的位深（bit）。",
        "ProfileName": "内嵌的 ICC 颜色配置文件名称，决定色彩如何还原。",
        "HasAlpha": "是否包含透明通道。",
        "Orientation": "图像显示方向；拍摄设备写入，查看器据此旋转画面。",

        // ---------------------------------------------------------------
        // TIFF / IFD0
        // ---------------------------------------------------------------
        "Make": "设备制造商。",
        "Model": "设备型号。",
        "Software": "生成或修改该文件的软件及版本。",
        "DateTime": "文件元数据的修改时间。",
        "XResolution": "水平分辨率。",
        "YResolution": "垂直分辨率。",
        "ResolutionUnit": "分辨率单位（英寸或厘米）。",
        "Artist": "作者/拍摄者。",
        "Copyright": "版权信息。",
        "HostComputer": "生成文件的计算机/设备。",
        "ImageDescription": "图像的文字描述。",

        // ---------------------------------------------------------------
        // EXIF
        // ---------------------------------------------------------------
        "ExposureTime": "曝光时间（快门速度），单位：秒。",
        "FNumber": "光圈值（F 值）；数值越小光圈越大、进光量越多。",
        "ExposureProgram": "相机的曝光程序模式。",
        "ISOSpeedRatings": "感光度（ISO）；数值越高对光越敏感，噪点也越多。",
        "ExifVersion": "EXIF 标准版本号。",
        "DateTimeOriginal": "原始拍摄时间。",
        "DateTimeDigitized": "图像数字化时间（通常与拍摄时间相同）。",
        "OffsetTime": "修改时间对应的时区偏移。",
        "OffsetTimeOriginal": "拍摄时间对应的时区偏移。",
        "OffsetTimeDigitized": "数字化时间对应的时区偏移。",
        "ShutterSpeedValue": "快门速度，APEX 制式值（已换算为实际秒数）。",
        "ApertureValue": "光圈，APEX 制式值（已换算为 F 值）。",
        "MaxApertureValue": "镜头最大光圈，APEX 制式值。",
        "BrightnessValue": "画面亮度，APEX 制式值。",
        "ExposureBiasValue": "曝光补偿，单位：EV。",
        "MeteringMode": "相机的测光模式。",
        "LightSource": "拍摄时的光源类型。",
        "Flash": "闪光灯工作状态（位掩码解码）。",
        "FocalLength": "镜头实际焦距，单位：毫米。",
        "FocalLengthIn35mmFilmFormat": "等效 35mm 全画幅焦距，便于比较视角。",
        "SubjectArea": "被摄主体在画面中的区域。",
        "SubjectDistanceRange": "被摄主体的距离范围。",
        "SubSecTime": "秒以下的时间精度（小数秒）。",
        "SubSecTimeOriginal": "拍摄时间的小数秒部分。",
        "SubSecTimeDigitized": "数字化时间的小数秒部分。",
        "ColorSpace": "图像色彩空间。",
        "ExifImageWidth": "图像宽度（EXIF 记录值），单位：像素。",
        "ExifImageHeight": "图像高度（EXIF 记录值），单位：像素。",
        "SensingMethod": "图像传感器类型。",
        "SceneType": "场景类型；通常为“直接拍摄”。",
        "SceneCaptureType": "相机使用的场景模式（标准/风光/人像/夜景）。",
        "ExposureMode": "曝光模式（自动/手动/包围曝光）。",
        "WhiteBalance": "白平衡模式。",
        "DigitalZoomRatio": "数码变焦倍率；1 表示未使用。",
        "GainControl": "图像增益处理。",
        "Contrast": "对比度处理。",
        "Saturation": "饱和度处理。",
        "Sharpness": "锐化处理。",
        "CustomRendered": "是否在相机内做了自定义图像处理。",
        "LensInfo": "镜头焦距与光圈范围信息。",
        "LensMake": "镜头制造商。",
        "LensModel": "镜头型号。",
        "LensSpecification": "镜头规格（焦距/光圈范围）。",
        "CompositeImage": "是否为多帧合成图像（如 iPhone 的 Deep Fusion）。",
        "UserComment": "用户或设备写入的注释。",
        "MakerNote": "厂商私有数据块（不同品牌结构不同）。",
        "FlashpixVersion": "FlashPix 格式版本。",
        "YCbCrPositioning": "色彩采样位置基准。",
        "ComponentsConfiguration": "颜色分量配置。",
        "CompressedBitsPerPixel": "压缩后每像素比特数。",
        "InteropIndex": "互操作性索引。",

        // ---------------------------------------------------------------
        // GPS
        // ---------------------------------------------------------------
        "GPSLatitudeRef": "纬度半球：N 北纬，S 南纬。",
        "GPSLatitude": "拍摄地纬度。",
        "GPSLongitudeRef": "经度半球：E 东经，W 西经。",
        "GPSLongitude": "拍摄地经度。",
        "GPSAltitudeRef": "海拔基准（海平面之上/之下）。",
        "GPSAltitude": "拍摄地海拔高度，单位：米。",
        "GPSTimeStamp": "GPS 定位的 UTC 时间。",
        "GPSDateStamp": "GPS 定位的 UTC 日期。",
        "GPSImgDirection": "拍摄时镜头朝向（方位角，度）。",
        "GPSImgDirectionRef": "方位角基准：T 真北，M 磁北。",
        "GPSDestBearing": "目的地方位角（度）。",
        "GPSDestBearingRef": "目的地方位角基准。",
        "GPSSpeedRef": "速度单位：K 公里/时，M 英里/时，N 节。",
        "GPSSpeed": "拍摄时移动速度。",
        "GPSTrack": "运动方向（方位角，度）。",
        "GPSTrackRef": "运动方向基准。",
        "GPSHPositioningError": "水平定位误差，单位：米；越小越精确。",
        "GPSDOP": "GPS 精度因子（DOP），越小定位越准。",
        "GPSMeasureMode": "GPS 测量模式（2D/3D）。",
        "GPSSatellites": "用于定位的卫星。",
        "GPSMapDatum": "GPS 坐标使用的测绘基准。",

        // ---------------------------------------------------------------
        // IPTC (editorial metadata)
        // ---------------------------------------------------------------
        "Caption/Abstract": "图片说明文字。",
        "Keywords": "关键词列表。",
        "Credit": "图片来源/供图方。",
        "Source": "内容原始来源。",
        "City": "拍摄地城市。",
        "Country-PrimaryLocationName": "拍摄地国家。",
        "By-line": "作者署名。",
        "Headline": "标题。",
        "ObjectName": "对象名称。",

        // ---------------------------------------------------------------
        // AVFoundation - General (movie / audio container)
        // ---------------------------------------------------------------
        "Duration": "媒体总时长。",
        "OverallBitRate": "整体码率（文件大小 ÷ 时长），衡量压缩程度。",
        "IsPlayable": "当前系统是否可以解码播放。",
        "IsExportable": "是否可以被转码导出。",
        "PreferredRate": "默认播放速率（1 = 原速）。",
        "PreferredVolume": "默认音量。",
        "Title": "标题。",
        "Creator": "创作者。",
        "Subject": "主题。",
        "Description": "描述。",
        "Publisher": "发行方。",
        "Contributor": "参与创作者。",
        "Type": "内容类型。",
        "Format": "内容格式。",
        "Language": "语言。",
        "Location": "拍摄位置（ISO 6709 格式）。",
        "CreationDate": "内容创建时间（通常为 UTC）。",
        "ModificationDate": "内容修改时间。",
        "ContentIdentifier": "内容唯一标识符（用于实况照片配对等）。",
        "LocationAccuracyHorizontal": "水平定位精度，单位：米。",
        "FullFrameRatePlaybackIntent": "是否应按完整帧率播放（高帧率视频标记）。",
        "LivePhotoAuto": "实况照片自动捕捉标记。",
        "LivePhotoVitalityScore": "实况照片“精彩程度”评分。",
        "LivePhotoVitalityScoringVersion": "实况照片评分算法版本。",
        "CameraLensIrisfnumber": "拍摄光圈值（F 值）。",

        // ---------------------------------------------------------------
        // Tracks
        // ---------------------------------------------------------------
        "TrackID": "轨道在容器内的编号。",
        "MediaType": "轨道类型：视频（video）、音频（soun）等。",
        "IsEnabled": "播放时该轨道是否默认启用。",
        "Codec": "编码格式（FourCC 及名称）。",
        "NaturalSize": "画面原始尺寸（宽 × 高，像素）。",
        "Dimensions": "编码尺寸（宽 × 高，像素）。",
        "NominalFrameRate": "标称帧率，单位：帧/秒。",
        "EstimatedDataRate": "该轨道的估算码率。",
        "Rotation": "播放时需要应用的旋转角度。",
        "SampleRate": "音频采样率，单位：Hz。",
        "Channels": "声道数。",
        "BitsPerChannel": "每个声道的量化位深（bit）。",
        "FormatID": "音频编码格式标识。",
        "ColorPrimaries": "色彩原色标准（如 BT.709、Display P3）。",
        "TransferFunction": "色彩传递函数（如 BT.709、PQ、HLG）。",
        "YCbCrMatrix": "YUV 与 RGB 转换矩阵。",
        "LanguageCode": "轨道语言代码。",
        "ExtendedLanguageTag": "扩展语言标签（BCP 47）。",

        // ---------------------------------------------------------------
        // ID3 / iTunes (audio)
        // ---------------------------------------------------------------
        "Artist": "艺术家/演唱者。",
        "Album": "专辑名称。",
        "AlbumArtist": "专辑艺术家（合辑时区别于单曲艺术家）。",
        "Genre": "音乐流派。",
        "TrackNumber": "在专辑中的音轨号。",
        "DiscNumber": "在多碟专辑中的碟号。",
        "Composer": "作曲者。",
        "Comment": "注释。",
        "Lyrics": "歌词。",
        "Year": "发行年份。",
        "BPM": "每分钟节拍数。",
        "Compilation": "是否为合辑。",
        "Artwork": "内嵌封面图片。",
        "Encoder": "编码软件。",
        "EncodedBy": "编码者。",
        "CopyrightNotice": "版权声明。"
    ]
}
