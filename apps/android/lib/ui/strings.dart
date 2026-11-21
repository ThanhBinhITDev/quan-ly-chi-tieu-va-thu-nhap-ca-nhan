class AppStrings {
  static const appTitle = 'Student Finance';
  static const tabHome = 'Trang chủ';
  static const tabTransactions = 'Giao dịch';
  static const tabBudget = 'Ngân sách';
  static const tabStats = 'Thống kê';
  static const tabAccount = 'Tài khoản';
  static const tabAdd = 'Thêm';
  static const accountTitle = 'Tài khoản';
  static const categoriesTitle = 'Danh mục';

  static const scenarioLabel = 'Trạng thái dữ liệu';

  /// Nhãn loại ví. Dùng chung cho màn Ví để danh sách và form không lệch chữ.
  static String walletTypeLabelOf(String type) => switch (type) {
    'cash' => walletTypeCash,
    'ewallet' => walletTypeEwallet,
    'bank' => walletTypeBank,
    'credit' => walletTypeCredit,
    _ => walletTypeCash,
  };
  static const scenarioReady = 'Dữ liệu mẫu';
  static const scenarioEmpty = 'Trống';
  static const scenarioError = 'Lỗi';
  static const scenarioOffline = 'Offline';

  static const loading = 'Đang tải dữ liệu...';
  static const errorTitle = 'Không thể tải dữ liệu';
  static const retry = 'Thử lại';
  static const offlineBanner =
      'Đang ngoại tuyến. Dữ liệu vẫn được lưu trên máy.';
  static const pending = 'Chờ đồng bộ';

  static const homeGreeting = 'Xin chào,';
  static const homeGreetingShort = 'Xin chào,';
  static const homeGuestName = 'bạn';
  static const homeOverview = 'Tổng quan hôm nay';
  static const homeToday = 'Hôm nay';
  static const balance = 'Số dư hiện tại';
  static const income = 'Thu nhập tháng';
  static const expense = 'Chi tiêu tháng';
  static const todayLimit = 'Hôm nay được tiêu';
  static const predictionTitle = 'Bạn có thể sử dụng tiền trong khoảng';
  static const predictionDays = 'ngày nữa';
  static const budgetSection = 'Ngân sách tháng';
  static const quickCategories = 'Ghi nhanh';
  static const savingsChallenge = 'Thử thách tiết kiệm';
  static const savingsEmpty = 'Đặt mục tiêu nhỏ đầu tiên để bắt đầu tiết kiệm.';
  static const savingsCreate = 'Tạo mục tiêu';
  static const savingsSaved = 'Đã để dành';
  static const savingsTarget = 'Mục tiêu';
  static const savingsDone = 'Đã hoàn thành';
  static const savingsMissing = 'Còn thiếu';
  static const savingsNewTitle = 'Mục tiêu mới';
  static const savingsNameLabel = 'Tên mục tiêu';
  static const savingsTargetLabel = 'Số tiền cần đạt';
  static const savingsAddAmount = 'Thêm vào mục tiêu';
  static const savingsAddConfirm = 'Thêm vào mục tiêu';
  static const savingsAdded = 'Đã thêm vào mục tiêu';
  static const savingsAmountLabel = 'Số tiền để dành thêm';
  static const savingsNameError = 'Nhập tên mục tiêu.';
  static const savingsTargetError = 'Nhập số tiền lớn hơn 0.';
  static const savingsGoalDone = 'Mục tiêu này đã hoàn thành.';
  static const monthBudget = 'Ngân sách tháng 11';
  static const categoryFood = 'Ăn uống';
  static const categoryTravel = 'Đi lại';
  static const categoryStudy = 'Học tập';
  static const categoryFun = 'Giải trí';
  static const todayLimitContext =
      'Từ ngân sách đã đặt, đã chi trong tháng và số ngày còn lại (tính cả hôm nay).';
  static const recentTransactions = 'Giao dịch gần đây';
  static const addTransaction = 'Thêm giao dịch';
  static const recordTitle = 'Ghi chép giao dịch';
  static const recordExpense = 'Chi tiêu';
  static const recordIncome = 'Thu nhập';
  static const recordCategoryTitle = 'Chọn danh mục';
  static const recordNoCategory = 'Chưa có danh mục nào để chọn.';
  static const recordAmountHint = 'Nhập số tiền, không cần dấu chấm';
  static const recordAmountError = 'Nhập số tiền lớn hơn 0.';
  static const recordClearAmount = 'Xoá số tiền';
  static const recordNoteHelper = 'Tối đa 120 ký tự';
  static const recordSaveExpense = 'Lưu khoản chi';
  static const recordSaveIncome = 'Lưu khoản thu';
  static const recordWhenLabel = 'Thời gian';
  static const recordPaymentMethod = 'Phương thức';
  static const recordIncomeSource = 'Nguồn thu';
  static const recordIncomeSourceHint = 'Ví dụ: Lương, Học bổng, Ba mẹ chuyển';
  // Ảnh ở đây là để nhớ khoản chi, không phải để chứng minh hoá đơn. Chữ trên
  // giao diện theo nghĩa đó: "kỷ niệm" gợi mở, "hoá đơn" gợi giấy tờ.
  static const recordReceipt = 'Ảnh kỷ niệm';
  static const recordReceiptAdd = 'Thêm ảnh';
  static const recordReceiptRemove = 'Xóa ảnh';
  static const recordReceiptTooLarge = 'Ảnh quá lớn, chọn ảnh khác.';
  static const recordPhotoTake = 'Chụp ảnh';
  static const recordPhotoPick = 'Chọn từ thư viện';
  static const recordPhotoSheetTitle = 'Thêm ảnh cho khoản chi';
  static const recordPhotoChange = 'Đổi ảnh';
  static const recordPhotoOptional = 'Không bắt buộc';
  static const recordPhotoHint = 'Một tấm ảnh để sau này nhớ lúc đó mình đã chi gì.';
  static const recordCameFromCamera = 'vừa chụp';
  static const paymentCash = 'Tiền mặt';
  static const paymentTransfer = 'Chuyển khoản';
  static const paymentCard = 'Thẻ';
  static const paymentEwallet = 'Ví điện tử';
  static const paymentOther = 'Khác';
  static String paymentMethodLabel(String? method) => switch (method) {
        'cash' => paymentCash,
        'bank_transfer' => paymentTransfer,
        'card' => paymentCard,
        'ewallet' => paymentEwallet,
        'other' => paymentOther,
        _ => paymentOther,
      };
  static const txDetailTitle = 'Chi tiết giao dịch';
  static const txEditTitle = 'Sửa giao dịch';
  static const txSaveChanges = 'Lưu thay đổi';
  static const txEditAction = 'Sửa';
  static const txDeleteAction = 'Xóa';
  static const txDeleteConfirm = 'Xóa giao dịch này? Bạn có thể ghi lại nếu cần.';
  static const txDeleted = 'Đã xóa giao dịch';
  static const txIncomeSourceLabel = 'Nguồn thu';
  static const txTimeLabel = 'Thời gian';
  static const txReceiptLabel = 'Ảnh kỷ niệm';
  static const recordMoreDetails = 'Thêm chi tiết';
  static const recordMoreDetailsHint = 'Ghi chú, nguồn thu, ảnh kỷ niệm';
  static const recordWalletTileLabel = 'Tài khoản/Ví';
  static const recordPaymentMethodTile = 'Phương thức thanh toán';
  static const txReceiptLoadFailed = 'Không tải được ảnh.';
  static const txDeleteFailed = 'Không xóa được giao dịch. Vui lòng thử lại.';
  static const backLabel = 'Quay lại';
  static const emptyHome =
      'Chưa có dữ liệu chi tiêu. Hãy thêm khoản chi đầu tiên.';
  static const emptyHomeAction = 'Tạo ngân sách';

  static const emptyTransactions = 'Chưa có giao dịch nào trong kỳ này.';
  static const emptyBudget =
      'Chưa có ngân sách. Tạo ngân sách đầu tiên để biết hạn mức mỗi ngày.';
  static const emptyStats =
      'Chưa đủ dữ liệu để thống kê. Hãy ghi vài giao dịch trước.';
  static const emptyStatsPrevious =
      'Tháng trước chưa có khoản chi nào được ghi lại.';
  static const backToCurrentMonth = 'Xem tháng này';
  static const createBudget = 'Tạo ngân sách';

  static const filterAll = 'Tất cả';
  static const filterExpense = 'Chi';
  static const filterIncome = 'Thu';
  static const rangeCurrent = 'Tháng này';
  static const rangePrevious = 'Tháng trước';

  // ── Sổ ảnh: lịch tháng + danh sách theo ngày ────────────────────────────
  static const viewList = 'Danh sách';
  static const viewCalendar = 'Lịch';
  static const calendarTitle = 'Sổ ảnh chi tiêu';
  static const calendarToday = 'Hôm nay';
  static const calendarEmptyMonth = 'Tháng này chưa có khoản chi nào.';
  static const calendarNoPhotoHint =
      'Khoản chi chưa có ảnh. Thêm ảnh để tháng này thành cuốn nhật ký.';
  static const calendarPhotosCount = 'khoản có ảnh';
  static const calendarDayTotal = 'Tổng ngày';
  static const calendarDayEmpty = 'Ngày này chưa ghi khoản nào.';
  static const calendarWeekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static String calendarMonthLabel(int month, int year) => 'Tháng $month, $year';
  static String calendarPhotoCount(int count) => '$count ảnh';

  static const totalExpense = 'Tổng chi';
  static const categories = 'Cơ cấu chi tiêu';
  static const dailyTrend = 'Chi tiêu theo ngày';
  static const comparePrevious = 'So với tháng trước';
  static const compareNoBaseline = 'Chưa có mốc so sánh';
  static const compareNoBaselineNote = 'Tháng trước chưa ghi khoản chi nào';
  static const sameAsPrevious = 'Không đổi';
  static String previousExpenseAmount(String amount) => 'Tháng trước: $amount';
  static const chartSummaryPrefix = 'Biểu đồ chi tiêu:';

  static const budgetPeriod = 'Kỳ áp dụng';
  static const budgetTotalMonth = 'Tổng ngân sách tháng';
  static const budgetSpentLabel = 'Đã dùng';
  static const budgetDayUnit = 'Ngày còn lại';
  static String budgetDaysLeft(int days) => 'Còn $days ngày';
  static const budgetAllocation = 'Phân bổ theo hũ';
  static const budgetJars = 'Hũ chi tiêu';
  static const budgetNothingSpent = 'Tháng này chưa có khoản chi nào trong hũ.';
  static const budgetTipTitle = 'Mẹo nhỏ';
  static const budgetTipOver =
      'Bạn đã dùng hết hạn mức tháng. Những khoản phát sinh từ giờ nên ghi '
      'riêng để tháng sau điều chỉnh lại hạn mức.';
  static String budgetTipOneJar(String name) =>
      'Hũ "$name" sắp chạm trần. Giảm khoản chi lớn nhất trong hũ này trước '
      'khi chạm giới hạn.';
  static const budgetTipWatch =
      'Bạn đang dùng khá nhanh hạn mức tháng. Giữ nhịp chi hiện tại thì sẽ '
      'hết trước cuối tháng.';
  static const budgetTipAlmostDone =
      'Tháng gần hết mà bạn vẫn còn nhiều hạn mức. Đừng tiêu cho đủ — phần '
      'dư này nên chuyển vào mục tiêu tiết kiệm.';
  static const budgetTipGood =
      'Bạn đang chi tiêu khá hợp lý! Hãy cố gắng giữ vững nhé.';
  static const budgetEditTotal = 'Sửa hạn mức tháng';
  static const budgetNew = 'Ngân sách mới';
  static const budgetCreate = 'Tạo ngân sách';
  static const budgetAddJar = 'Thêm hũ';
  static const budgetAmountLabel = 'Hạn mức';
  static const budgetUnassigned = 'Chưa chia';
  static const budgetScopeTotalShort = 'Tổng';
  static const budgetSave = 'Lưu hạn mức';
  static const budgetAmountError = 'Nhập hạn mức lớn hơn 0.';
  static const budgetScopeTotal = 'Tổng tất cả khoản chi';
  static const budgetScopeLabel = 'Áp dụng cho';
  static const budgetSaved = 'Đã lưu ngân sách.';
  static const budgetExists =
      'Đã có hạn mức cho mục này, sửa trực tiếp bên dưới.';
  static const budgetJarHint = 'Chạm vào hũ để sửa hạn mức.';
  static const budgetRemaining = 'Còn lại';
  static const budgetUsed = 'Đã dùng';

  static const settings = 'Cài đặt';
  static const unknown = 'Khác';

  static const amountLabel = 'Số tiền';
  static const categoryLabel = 'Danh mục';
  static const walletLabel = 'Ví';
  static const noteLabel = 'Ghi chú';
  static const walletCash = 'Tiền mặt';
  static const walletBank = 'Ngân hàng';
  static const pickCategory = 'Chọn danh mục.';
  static const pickWallet = 'Chọn ví.';
  static const save = 'Lưu giao dịch';
  static const saveFailed = 'Không lưu được giao dịch. Vui lòng thử lại.';

  // Đăng nhập / đăng ký
  static const loginTitle = 'Đăng nhập';
  static const loginSubtitle = 'Quản lý chi tiêu của bạn mọi lúc, mọi nơi.';
  static const emailLabel = 'Email';
  static const passwordLabel = 'Mật khẩu';
  static const displayNameLabel = 'Tên hiển thị';
  static const signInAction = 'Đăng nhập';
  static const signUpAction = 'Tạo tài khoản';
  static const switchToSignUp = 'Chưa có tài khoản? Đăng ký';
  static const switchToSignIn = 'Đã có tài khoản? Đăng nhập';
  static const signOutAction = 'Đăng xuất';
  static const emailInvalid = 'Email không hợp lệ.';
  static const passwordTooShort = 'Mật khẩu cần ít nhất 6 ký tự.';
  static const nameRequired = 'Vui lòng nhập tên hiển thị.';
  static const signUpNeedsConfirm =
      'Đã tạo tài khoản. Kiểm tra email để xác nhận rồi đăng nhập.';
  static const notConfiguredTitle = 'Chưa cấu hình máy chủ';
  static const notConfiguredBody =
      'Ứng dụng chưa có SUPABASE_URL và SUPABASE_ANON_KEY nên không thể đăng '
      'nhập. Chạy lại với --dart-define để cấu hình.';
  static const continueOffline = 'Xem dữ liệu mẫu';
  static const orDivider = 'hoặc';
  static const signUpSubtitle =
      'Tạo tài khoản để bắt đầu ghi lại thu nhập và chi tiêu.';
  static const signingIn = 'Đang đăng nhập...';

  // Điều khoản pháp lý & đồng ý
  static const consentPrefix = 'Tôi đã đọc và đồng ý với';
  static const termsOfUse = 'Điều khoản sử dụng';
  static const privacyPolicy = 'Chính sách quyền riêng tư';
  static const consentAnd = 'và';
  static const consentRequired =
      'Bạn cần đọc và đồng ý với Điều khoản sử dụng và Chính sách quyền '
      'riêng tư trước khi tiếp tục.';
  static const consentDataNote =
      'Việc đăng nhập đồng nghĩa bạn đồng ý để chúng tôi xử lý email, tên hiển '
      'thị và dữ liệu chi tiêu bạn tự nhập, theo đúng Chính sách quyền riêng tư.';
  static const legalUpdatedAt = 'Cập nhật lần cuối: 20/11/2026';
  static const legalVersion = '1.0';
  static const readLegal = 'Đọc điều khoản';
  static const closeLabel = 'Đóng';
  static const cancelLabel = 'Huỷ';
  static const legalTabTerms = 'Điều khoản';
  static const legalTabPrivacy = 'Quyền riêng tư';

  // Hồ sơ người dùng
  static const profile = 'Hồ sơ của bạn';
  static const profileEdit = 'Sửa hồ sơ';
  static const displayNameLabelShort = 'Tên hiển thị';
  static const usernameLabel = 'Tên người dùng';
  static const usernameHint = 'Chỉ chữ thường, số, dấu chấm và gạch dưới';
  static const emailChange = 'Đổi email';
  static const emailChangeNote =
      'Email dùng để đăng nhập và nhận thông báo. Đổi email cần xác nhận lại.';
  static const avatarChange = 'Đổi ảnh đại diện';
  static const avatarHint = 'Ảnh vuông, tối thiểu 256×256, tối đa 5 MB';
  static const saveProfile = 'Lưu thay đổi';
  static const profileSaved = 'Đã lưu hồ sơ.';
  static const cropTitle = 'Cắt ảnh đại diện';
  static const cropHint = 'Kéo và thu phóng để chọn vùng ảnh';
  static const cropApply = 'Dùng ảnh này';
  static const cropCancel = 'Huỷ';
  static const pickFromGallery = 'Chọn từ thư viện';
  static const pickFromCamera = 'Chụp ảnh mới';
  static const avatarTooLarge = 'Ảnh quá lớn, chọn ảnh dưới 5 MB.';
  static const memberSince = 'Thành viên từ';

  // Ví của tôi
  static const walletsTitle = 'Ví của tôi';
  static const walletsOpen = 'Mở ví';
  static const walletsTotal = 'Tổng số dư các ví';
  static String walletsCount(int count) =>
      count == 0 ? 'Chưa có ví' : '$count ví đang dùng';
  static const walletsShareNote =
      'Số dư của mỗi ví bằng số dư ban đầu cộng thu và trừ chi. Sửa số dư ban '
      'đầu khi nhập nhầm, không phải khi muốn thêm tiền — khoản thêm nên ghi '
      'thành giao dịch thu nhập để giữ đúng lịch sử.';
  static const walletAdd = 'Thêm ví';
  static const walletAddAction = 'Tạo ví';
  static const walletEdit = 'Sửa ví';
  static const walletSave = 'Lưu ví';
  static const walletDelete = 'Xoá ví';
  static const walletActions = 'Thao tác với ví';
  static String walletDeleteConfirm(String name) =>
      'Xoá ví "$name"? Giao dịch cũ vẫn được giữ, nhưng ví sẽ không còn trong '
      'danh sách và không tính vào tổng số dư.';
  static const walletDeleted = 'Đã xoá ví';
  static const walletSaveFailed = 'Không lưu được ví.';
  static const walletLimitReached =
      'Gói miễn phí chỉ cho phép 3 ví đang dùng. Xoá bớt một ví rồi thêm lại.';
  static const walletCurrent = 'hiện tại';
  static String walletInitialShort(String amount) => 'ban đầu $amount';
  static const walletEmptyTitle = 'Chưa có ví nào';
  static const walletEmptyBody =
      'Thêm ví đầu tiên kèm số tiền đang có để trang chủ hiện đúng số dư của bạn.';
  static const walletNameLabel = 'Tên ví';
  static const walletNameRequired = 'Nhập tên ví.';
  static const walletNameTooLong = 'Tên ví tối đa 80 ký tự.';
  static const walletTypeLabel = 'Loại ví';
  static const walletTypeCash = 'Tiền mặt';
  static const walletTypeEwallet = 'Ví điện tử';
  static const walletTypeBank = 'Ngân hàng';
  static const walletTypeCredit = 'Thẻ tín dụng';
  static const walletBalanceLabel = 'Số dư ban đầu';
  static const walletBalanceHint =
      'Số tiền đang có trong ví lúc bắt đầu dùng ứng dụng.';
  static const walletBalanceInvalid = 'Số dư phải là số không âm.';
  static const noWalletTitle = 'Chưa có số dư';
  static const noWalletBody =
      'Thêm ví kèm số tiền đang có để biết mình còn bao nhiêu.';

  // Thông báo
  static const notifications = 'Thông báo';
  static const notificationsUnread = 'tin chưa đọc';
  static const notificationsEmptyTitle = 'Chưa có thông báo nào';
  static const notificationsEmptyBody =
      'Cảnh báo ngân sách và báo cáo tháng sẽ xuất hiện ở đây khi có số liệu.';
  static const notificationJustNow = 'Vừa xong';
  static String notificationMinutesAgo(int minutes) => '$minutes phút trước';
  static String notificationHoursAgo(int hours) => '$hours giờ trước';
  static String notificationDaysAgo(int days) => '$days ngày trước';
}
