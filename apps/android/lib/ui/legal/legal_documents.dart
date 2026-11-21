/// Nội dung pháp lý hiển thị trong app.
///
/// Văn bản được viết cho bản phát hành 1.0. Khi thay đổi nội dung phải tăng
/// [LegalDocs.version]: bản đã lưu trong máy dùng để biết người dùng đã đồng ý
/// phiên bản nào, và app sẽ hỏi lại khi phiên bản khác đi.
///
/// Căn cứ pháp lý tham chiếu khi soạn:
/// - Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân (đồng ý, mục đích,
///   lưu trữ, quyền của chủ thể dữ liệu).
/// - Luật An ninh mạng 2018 và Luật Giao dịch điện tử 2023.
/// - Bộ luật Dân sự 2015 về giao kết hợp đồng điện tử.
library;

class LegalSection {
  const LegalSection({required this.heading, required this.paragraphs});

  final String heading;
  final List<String> paragraphs;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String title;
  final String summary;
  final List<LegalSection> sections;
}

class LegalDocs {
  const LegalDocs._();

  /// Tăng số này mỗi khi sửa nội dung điều khoản/quyền riêng tư.
  static const String version = '1.0';
  static const String updatedAt = '20/11/2026';

  static const terms = LegalDocument(
    title: 'Điều khoản sử dụng',
    summary:
        'Student Finance là công cụ ghi chép và phân tích chi tiêu cá nhân. '
        'Bạn giữ toàn quyền với dữ liệu mình nhập; chúng tôi chỉ xử lý để '
        'hiển thị lại cho chính bạn.',
    sections: [
      LegalSection(
        heading: '1. Chấp nhận điều khoản',
        paragraphs: [
          'Khi đánh dấu ô đồng ý và bấm đăng nhập hoặc tạo tài khoản, bạn xác '
              'nhận đã đọc, hiểu và đồng ý bị ràng buộc bởi Điều khoản sử dụng '
              'này cùng Chính sách quyền riêng tư đi kèm.',
          'Nếu bạn không đồng ý, vui lòng không tiếp tục sử dụng ứng dụng. Bạn '
              'có thể đóng ứng dụng bất cứ lúc nào mà không phát sinh nghĩa vụ.',
          'Bạn phải đủ 16 tuổi trở lên để tự tạo tài khoản. Người dưới 16 tuổi '
              'chỉ sử dụng khi có sự đồng ý và giám sát của cha, mẹ hoặc người '
              'giám hộ hợp pháp.',
        ],
      ),
      LegalSection(
        heading: '2. Tài khoản của bạn',
        paragraphs: [
          'Bạn chịu trách nhiệm bảo mật mật khẩu và mọi hoạt động diễn ra dưới '
              'tài khoản của mình. Không chia sẻ tài khoản cho người khác và '
              'không dùng chung một tài khoản cho nhiều người.',
          'Thông tin đăng ký phải chính xác. Nếu phát hiện truy cập trái phép, '
              'hãy đổi mật khẩu ngay và liên hệ với chúng tôi.',
          'Chúng tôi có thể tạm khoá tài khoản khi có dấu hiệu lạm dụng, tấn '
              'công, hoặc khi pháp luật yêu cầu. Trong trường hợp đó, bạn luôn '
              'có quyền yêu cầu xuất dữ liệu của mình.',
        ],
      ),
      LegalSection(
        heading: '3. Dữ liệu bạn nhập vào',
        paragraphs: [
          'Dữ liệu giao dịch, ví, ngân sách, mục tiêu bạn nhập thuộc về bạn. '
              'Chúng tôi không bán, không cho thuê và không chia sẻ dữ liệu này '
              'cho bên thứ ba vì mục đích quảng cáo.',
          'Bạn cấp cho chúng tôi quyền xử lý dữ liệu ở mức tối thiểu cần thiết: '
              'lưu trữ, tính toán số dư và thống kê, đồng bộ giữa các thiết bị '
              'của chính bạn. Quyền này chấm dứt khi bạn xoá dữ liệu hoặc xoá '
              'tài khoản.',
          'Bạn không được nhập dữ liệu trái pháp luật, dữ liệu xâm phạm quyền '
              'của người khác, hoặc thông tin của người khác khi chưa được họ '
              'đồng ý.',
        ],
      ),
      LegalSection(
        heading: '4. Nội dung do ứng dụng tạo ra',
        paragraphs: [
          'Các dự báo như "số ngày còn dùng được tiền", "hôm nay được tiêu" '
              'được tính từ dữ liệu bạn nhập. Đây là gợi ý tham khảo, không phải '
              'tư vấn tài chính, đầu tư hay pháp lý.',
          'Chúng tôi nỗ lực để phép tính đúng, nhưng không bảo đảm ứng dụng '
              'không có sai sót. Quyết định chi tiêu vẫn là trách nhiệm của bạn.',
        ],
      ),
      LegalSection(
        heading: '5. Gói miễn phí và gói trả phí',
        paragraphs: [
          'Ứng dụng có gói miễn phí với giới hạn số ví đang hoạt động và một số '
              'tính năng nâng cao. Giới hạn được hiển thị rõ trong ứng dụng '
              'trước khi bạn chạm tới.',
          'Gói trả phí (nếu bạn chọn mua) được tính theo chu kỳ tháng hoặc năm, '
              'gia hạn tự động cho tới khi bạn huỷ. Việc huỷ có hiệu lực từ kỳ '
              'tiếp theo; bạn vẫn dùng được tới hết kỳ đã trả tiền.',
          'Giá và quyền lợi của gói trả phí có thể thay đổi. Thay đổi chỉ áp '
              'dụng từ kỳ thanh toán kế tiếp và luôn được thông báo trước.',
        ],
      ),
      LegalSection(
        heading: '6. Hành vi bị cấm',
        paragraphs: [
          'Không dò quét, tấn công, làm quá tải hệ thống; không truy cập dữ liệu '
              'của người dùng khác; không dịch ngược hay can thiệp vào ứng dụng '
              'để vượt giới hạn gói dịch vụ.',
          'Không dùng ứng dụng để rửa tiền, ghi chép giao dịch bất hợp pháp, '
              'hoặc bất kỳ mục đích nào bị pháp luật Việt Nam nghiêm cấm.',
        ],
      ),
      LegalSection(
        heading: '7. Giới hạn trách nhiệm',
        paragraphs: [
          'Ứng dụng được cung cấp "nguyên trạng". Trong phạm vi pháp luật cho '
              'phép, chúng tôi không chịu trách nhiệm cho thiệt hại gián tiếp, '
              'mất lợi nhuận, hoặc mất dữ liệu do nguyên nhân ngoài tầm kiểm '
              'soát như mất thiết bị, hỏng ổ cứng, hoặc dịch vụ mạng gián đoạn.',
          'Bạn nên tự sao lưu dữ liệu quan trọng. Ứng dụng có chức năng xuất dữ '
              'liệu để bạn lưu giữ độc lập.',
        ],
      ),
      LegalSection(
        heading: '8. Thay đổi điều khoản',
        paragraphs: [
          'Khi điều khoản thay đổi, ứng dụng sẽ hiển thị lại bước đồng ý và ghi '
              'rõ phiên bản mới. Nếu bạn không đồng ý với bản mới, bạn có thể '
              'ngừng sử dụng và yêu cầu xoá tài khoản.',
        ],
      ),
      LegalSection(
        heading: '9. Luật áp dụng và liên hệ',
        paragraphs: [
          'Điều khoản này được điều chỉnh bởi pháp luật Việt Nam. Tranh chấp '
              'được giải quyết thông qua thương lượng trước; nếu không thành, '
              'đưa ra Toà án có thẩm quyền tại Việt Nam.',
          'Mọi thắc mắc về điều khoản, vui lòng gửi tới bộ phận hỗ trợ trong '
              'ứng dụng.',
        ],
      ),
    ],
  );

  static const privacy = LegalDocument(
    title: 'Chính sách quyền riêng tư',
    summary:
        'Chúng tôi thu thập ít nhất có thể: email để đăng nhập, tên hiển thị '
        'để chào bạn, và dữ liệu chi tiêu do chính bạn nhập. Không quảng cáo, '
        'không bán dữ liệu.',
    sections: [
      LegalSection(
        heading: '1. Chúng tôi thu thập gì',
        paragraphs: [
          'Thông tin tài khoản: email, mật khẩu (lưu dưới dạng băm, chúng tôi '
              'không đọc được mật khẩu của bạn), tên hiển thị, và ảnh đại diện '
              'nếu bạn tải lên.',
          'Dữ liệu tài chính do bạn nhập: giao dịch, ví, danh mục, ngân sách, '
              'mục tiêu. Đây là dữ liệu bạn chủ động cung cấp, không phải dữ '
              'liệu chúng tôi thu thập ngầm.',
          'Dữ liệu kỹ thuật tối thiểu: mã thiết bị để đồng bộ và chống đăng '
              'nhập trái phép, thời điểm đăng nhập gần nhất, phiên bản ứng dụng.',
          'Chúng tôi KHÔNG thu thập: danh bạ, tin nhắn, vị trí GPS, lịch sử duyệt '
              'web, hay danh sách ứng dụng khác trên máy bạn.',
        ],
      ),
      LegalSection(
        heading: '2. Mục đích xử lý',
        paragraphs: [
          'Để tạo và xác thực tài khoản, hiển thị số dư và thống kê chi tiêu của '
              'bạn, đồng bộ dữ liệu giữa các thiết bị bạn đăng nhập.',
          'Để bảo vệ tài khoản: phát hiện đăng nhập bất thường, chặn dò mật '
              'khẩu, ghi log an ninh.',
          'Để hỗ trợ bạn khi bạn yêu cầu trợ giúp. Chúng tôi chỉ xem dữ liệu của '
              'bạn khi bạn yêu cầu hoặc khi cần điều tra sự cố bạn báo.',
          'Chúng tôi không dùng dữ liệu chi tiêu của bạn để huấn luyện mô hình, '
              'không bán cho nhà quảng cáo, không chia sẻ cho đơn vị chấm điểm '
              'tín dụng.',
        ],
      ),
      LegalSection(
        heading: '3. Cơ sở pháp lý và sự đồng ý',
        paragraphs: [
          'Việc xử lý dựa trên sự đồng ý của bạn theo Nghị định 13/2023/NĐ-CP, '
              'và trên việc thực hiện hợp đồng cung cấp dịch vụ mà bạn đã giao '
              'kết khi tạo tài khoản.',
          'Bạn có thể rút lại sự đồng ý bất cứ lúc nào bằng cách xoá tài khoản. '
              'Sau khi rút, chúng tôi ngừng xử lý và xoá dữ liệu theo mục 6.',
          'Sự đồng ý của bạn là tự nguyện: không có ô đồng ý nào được đánh dấu '
              'sẵn, và bạn không bị ép buộc phải đồng ý để dùng các tính năng cơ '
              'bản khác ngoài việc tạo tài khoản.',
        ],
      ),
      LegalSection(
        heading: '4. Lưu ở đâu và bảo vệ thế nào',
        paragraphs: [
          'Dữ liệu được lưu trên máy chủ đặt tại nhà cung cấp hạ tầng đám mây có '
              'chứng nhận bảo mật, cơ sở dữ liệu đặt trong vùng riêng. Kết nối '
              'giữa ứng dụng và máy chủ dùng HTTPS.',
          'Trên thiết bị, token đăng nhập được lưu trong kho bảo mật của hệ điều '
              'hành (Keychain trên iOS, EncryptedSharedPreferences trên Android), '
              'không lưu dạng văn bản thuần.',
          'Mỗi tài khoản chỉ truy cập được dữ liệu của chính mình. Máy chủ kiểm '
              'tra danh tính từ token ở mọi yêu cầu, không tin mã người dùng do '
              'ứng dụng gửi lên.',
          'Mật khẩu được băm bằng thuật toán một chiều có muối. Nhân viên của '
              'chúng tôi không thể đọc mật khẩu của bạn.',
        ],
      ),
      LegalSection(
        heading: '5. Chia sẻ với bên thứ ba',
        paragraphs: [
          'Chúng tôi chỉ chia sẻ dữ liệu với các nhà cung cấp hạ tầng cần thiết '
              'để vận hành ứng dụng (máy chủ, cơ sở dữ liệu, dịch vụ gửi email '
              'xác nhận), và chỉ ở mức tối thiểu cần thiết.',
          'Chúng tôi có thể cung cấp dữ liệu khi có yêu cầu hợp pháp bằng văn bản '
              'từ cơ quan nhà nước có thẩm quyền. Trừ khi bị pháp luật cấm, chúng '
              'tôi sẽ thông báo cho bạn biết.',
          'Chúng tôi không bán dữ liệu cá nhân dưới bất kỳ hình thức nào.',
        ],
      ),
      LegalSection(
        heading: '6. Lưu bao lâu và xoá thế nào',
        paragraphs: [
          'Dữ liệu được lưu trong suốt thời gian tài khoản còn hoạt động. Khi bạn '
              'xoá tài khoản, dữ liệu cá nhân được xoá trong vòng 30 ngày, trừ '
              'phần phải giữ theo quy định pháp luật (ví dụ hoá đơn, log giao '
              'dịch theo yêu cầu của cơ quan thuế).',
          'Bản sao lưu định kỳ có thể còn dữ liệu tối đa 90 ngày trước khi bị ghi '
              'đè hoàn toàn. Bản sao lưu không dùng cho mục đích nào khác.',
          'Khi bạn xoá một giao dịch, bản ghi được đánh dấu xoá và loại khỏi mọi '
              'phép tính ngay lập tức; bản ghi gốc được xoá hẳn theo cùng lịch '
              'trên.',
        ],
      ),
      LegalSection(
        heading: '7. Quyền của bạn',
        paragraphs: [
          'Bạn có quyền: biết dữ liệu nào đang được xử lý, yêu cầu bản sao, yêu '
              'cầu chỉnh sửa, yêu cầu xoá, rút lại sự đồng ý, và phản đối việc '
              'xử lý.',
          'Bạn có thể tự thực hiện phần lớn các quyền này ngay trong ứng dụng: '
              'sửa hồ sơ, xuất dữ liệu, xoá tài khoản. Với yêu cầu khác, gửi tới '
              'bộ phận hỗ trợ; chúng tôi phản hồi trong vòng 72 giờ.',
          'Nếu cho rằng quyền của mình bị xâm phạm, bạn có quyền khiếu nại tới cơ '
              'quan quản lý về an ninh mạng và bảo vệ dữ liệu cá nhân.',
        ],
      ),
      LegalSection(
        heading: '8. Trẻ em',
        paragraphs: [
          'Ứng dụng không hướng tới trẻ em dưới 16 tuổi. Chúng tôi không cố ý '
              'thu thập dữ liệu của trẻ em dưới 16 tuổi khi chưa có sự đồng ý '
              'của người giám hộ. Nếu phát hiện, chúng tôi sẽ xoá.',
        ],
      ),
      LegalSection(
        heading: '9. Thay đổi chính sách',
        paragraphs: [
          'Khi chính sách thay đổi quan trọng, ứng dụng sẽ hiển thị lại bước đồng '
              'ý kèm phiên bản mới. Bạn luôn biết mình đang đồng ý với phiên bản '
              'nào vì số phiên bản được hiển thị ngay trên màn hình đồng ý.',
        ],
      ),
    ],
  );
}
