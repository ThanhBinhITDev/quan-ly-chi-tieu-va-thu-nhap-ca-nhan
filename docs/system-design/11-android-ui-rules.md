# 11 - Quy tac xay dung giao dien Android

**Phien ban:** 1.0  
**Nen tang:** Android 8+ (API 26), Flutter 3.24+, Material 3  
**Ap dung cho:** `apps/android/`  
**Nguon du lieu:** local-first voi drift, dong bo qua API NestJS

Tai lieu nay la bo quy tac bat buoc khi xay dung giao dien Android cho Student Finance. Khi co mau thuan, uu tien theo thu tu: quyet dinh san pham da chot, wireframe, tai lieu nay, sau do moi den tuy chon rieng cua component.

## 1. Nguyen tac san pham

- Mo app la thay ngay tinh hinh tai chinh hom nay; khong chen landing page hoac man hinh gioi thieu dai.
- Giao dich duoc ghi offline va cap nhat UI ngay sau thao tac. Khong hien man hinh "dang luu" chi de cho server.
- So tien, tong chi, ngan sach, han muc moi ngay va tien do muc tieu phai do model tinh tu du lieu that; UI khong tu sinh so.
- Moi loi dong bo phai hien thi trang thai de hieu va cho phep thu lai, khong lam mat du lieu da nhap.
- Uu tien thao tac mot tay, doc nhanh, nhap nhanh va cuon muot tren may Android 4 GB RAM.

## 2. Cau truc dieu huong

Dung `NavigationBar` Material 3 voi dung 4 tab:

1. Trang chu
2. Giao dich
3. Ngan sach
4. Thong ke

- Tai khoan mo tu icon settings o header Trang chu; khong tao tab thu nam.
- Man hinh con dung `AppBar` voi nut back tieu chuan Android.
- Khong dat hai thanh dieu huong cung luc, khong dung drawer cho luong su dung hang ngay.
- Tab hien tai phai co ca mau va chi dan chu, khong chi dua vao icon.
- Nut them giao dich la `FloatingActionButton` hoac nut them noi dung ro rang, luon de trong tam voi ngon cai.
- Khi ban phim mo, noi dung va nut xac nhan phai duoc cuon vao tam nhin.

## 3. He thong thi giac

### 3.1 Mau

Dung mau da chot trong wireframe, tap trung vao do tuong phan va y nghia trang thai:

- Primary: xanh la `#2D7C3D`.
- Primary container: xanh la nhat cho selection va khu vuc nhan dien.
- Surface: nen trung tinh sang; khong dung gradient.
- Expense: do dam, income: xanh la dam, transfer: xanh duong trung tinh.
- Warning: amber; error: do; success: xanh la.
- Mau khong duoc la kenh duy nhat: giao dich phai co icon/nhan text hoac dau tien.
- Ho tro dark theme bang Material color scheme; khong dao mau bang cach lam toi tuy tien.

### 3.2 Chu va khoang cach

- Dung `TextTheme` cua Material 3, khong tao hang chuc co chu tuy chinh.
- Tieu de man hinh dung `titleLarge`; tieu de khu vuc dung `titleMedium`; noi dung danh sach dung `bodyLarge` hoac `bodyMedium`.
- So tien chinh co the lon hon noi dung xung quanh nhung phai co gioi han kich thuoc; neu dai thi xuong dong hoac rut gon co kiem soat.
- Letter spacing mac dinh cua Material 3; khong dung letter spacing am.
- Khoang cach co so theo he 4 dp; padding thao tac thuong dung 16 dp.
- Vung cham toi thieu 48 x 48 dp; icon button phai co tooltip cho icon khong pho bien.
- Card chi dung cho mot nhom thong tin hoac mot item lap lai; bo goc toi da 8 dp neu khong co ly do tu Material 3.

## 4. Quy tac component

- Button text chi dung cho lenh ro rang; thao tac icon quen thuoc dung `IconButton` co tooltip.
- Dung `FilledButton` cho hanh dong chinh, `OutlinedButton` cho hanh dong phu, `TextButton` cho hanh dong it quan trong.
- Dung `ChoiceChip`/segmented control cho lua chon it muc; dung `DropdownMenu` cho danh sach dai.
- Dung `Switch` cho tuy chon bat/tat, `Checkbox` cho nhieu lua chon, `Radio` cho lua chon duy nhat.
- Dung `ModalBottomSheet` cho lua chon ngan, loc va thao tac nhanh; dung man hinh rieng cho form dai.
- Khong long card trong card. Khong dung text trong rounded rectangle neu mot icon quen thuoc da du.
- Moi component co trang thai loading, empty, error, disabled va success khi phu hop.
- Hien thi `SnackBar` cho ket qua ngan; khong dung SnackBar cho loi can thao tac phuc hoi.

## 5. Quy tac theo man hinh

### 5.1 Trang chu

- Header co loi chao ngan, ngay hien tai va icon settings.
- Khoi tong quan dat tren cung: so du tinh, tong thu, tong chi va chi tieu hom nay.
- Khu vuc "hom nay duoc tieu" phai hien thi cong thuc/ngu canh ngan gon, khong dua ra con so khong co du lieu.
- Hien thi giao dich gan day va trang thai dong bo neu co.
- Co loi goi hanh dong them giao dich; khong de man hinh trong neu tai khoan moi.

### 5.2 Giao dich

- Danh sach nhom theo ngay, item co so tien, danh muc, vi, ghi chu ngan va trang thai pending.
- Filter theo khoang ngay, loai, vi va danh muc; filter dang ap dung phai nhin thay va xoa duoc.
- Swipe action chi dung cho thao tac an toan; xoa phai co undo va khong xoa vinh vien ngay tren gesture.
- Form nhap nhanh uu tien so tien, loai, danh muc va vi; focus vao truong so tien.
- Validate inline, bao loi gan truong va khong chi bao loi sau khi submit.

### 5.3 Ngan sach

- Moi budget co thanh tien do, da dung, con lai va khoang thoi gian.
- Dung mau canh bao theo nguong; van hien thi phan tram bang text.
- Empty state phai co nut tao ngan sach dau tien.
- Khong dung bieu do thay cho so lieu can doc chinh xac.

### 5.4 Thong ke

- Cho chon khoang thoi gian truoc khi hien bieu do.
- Bieu do phai co legend, nhan truc va tong so tuong ung; tap vao diem/bucket de xem chi tiet.
- Khong dung mau gan nhau cho cac danh muc; phai co text thay the va ho tro screen reader.
- Neu khong du du lieu, hien thi trang thai empty co giai thich thay vi bieu do gia.

### 5.5 Split Bill

- Hien thi ten nhom, so thanh vien, vai tro cua nguoi dung va trang thai nhom.
- Danh sach chi phi chung phai co ten khoan chi, ngay, tong tien, nguoi tra ho, danh sach nguoi tham gia va phan tien cua tung nguoi.
- Co nut `Them chi phi` de mo form nhap khoan chi; form phai cho phep chon phuong thuc chia va kiem tra tong cac phan chia bang tong tien.
- Khoi "Ai no ai" hien so tien server tra ve, khong tu tinh lai o app; cho phep mo chi tiet va danh dau phan cua minh da thanh toan.
- Phan phai thu/phai tra phai tach khoi so du ca nhan; khong cong nham vao tong chi ca nhan.
- Nguoi dung chi duoc danh dau phan cua minh da thanh toan.
- Hanh dong xoa/sua khoan chi chi hien cho nguoi tra hoac chu nhom theo quyen server.
- Khi thanh vien da roi nhom, hien thi du lieu lich su o che do chi doc neu API cho phep.

### 5.6 Thu thach tiet kiem / Muc tieu

- Man hinh chi tiet hien ten muc tieu, icon, so tien can dat, so tien da tich luy, phan tram tien do va han chot neu co.
- Phan tram do tien do tinh tu `saved_amount / target_amount`, gioi han trong 0-100% de hien thi; khong tinh `saved_amount` tu cac giao dich va khong gan muc tieu vao vi.
- Thanh tien do phai co nhan text, vi du `3.200.000 / 8.000.000 d (40%)`, de khong phu thuoc vao mau sac.
- Nut `Them tien` mo `ModalBottomSheet` hoac form ngan, nhan so tien tuyet doi muon cap nhat va hien so tien moi truoc khi xac nhan.
- Khong cong lap gia tri khi retry; client ghi gia tri `saved_amount` moi theo hop dong API va dong bo idempotent.
- Lich su cac lan cap nhat muc tieu phai phan biet la lich su UI neu API co tra ve; neu chua co bang lich su thi khong gia lap danh sach tu giao dich.
- Trang thai can co: chua co muc tieu, dang tiet kiem, dat 100%, qua han va loi cap nhat.
- Khi dat muc tieu, hien thong bao thanh cong va van cho phep xem/chinh sua; khong tu dong tao giao dich thu/chi.

### 5.7 Tro ly tai chinh AI

- Day la man hinh rieng giai doan AI; MVP khong duoc gia vo ket qua AI khi endpoint chua san sang.
- Giao dien gom loi chao ngan, danh sach tin nhan theo vai tro, vung nhap cau hoi va cac chip cau hoi goi y co the bam.
- Chip goi y mac dinh gom: `Thang nay toi tieu nhieu nhat o dau?`, `Toi con bao nhieu tien den cuoi thang?`, `Ngan sach nao sap vuot?`.
- Tin nhan dang gui co trang thai loading nho, khong khoa tab va khong lam mat noi dung da nhap.
- Cau tra loi phai dua tren du lieu tai chinh da truy van; phan so lieu do server tinh, khong de LLM tu sinh con so.
- Moi cau tra loi hien `data_refs` hoac nut mo den man hinh/bao cao nguon khi API tra ve; neu khong co du lieu thi noi ro khong du thong tin.
- Khi offline hoac vuot quota, hien loi giai thich va nut thu lai/nang cap; khong hien cau tra loi mau nhu ket qua that.
- Khong hien avatar/trang tri lam tang dien tich chat hoac che noi dung; uu tien doc va kiem chung.
- Lich su chat doc tu local cache neu co, nhung phai gan nhan tin chua dong bo neu chua gui thanh cong.

### 5.8 Phan tich mua sam - "Toi co nen mua mon nay?"

- Form nhan ten mon hang va gia tien; co the mo tu AI Assistant nhung ket qua phan tich phai la man hinh/khối co the kiem chung.
- Khoi "Phan tich nhanh" gom it nhat 3 dong: so du hien tai, sau khi mua con bao nhieu, va con du dung den cuoi chu ky ngan sach hay khong.
- Moi dong co icon trang thai, nhan text va so lieu nguon; mau chi la kenh phu, khong dung mau don doc.
- Ket luan phai chon mot trang thai ro rang: `Ban co the mua`, `Nen can nhac` hoac `Chua nen mua`; khong dung ket luan vua cho phep vua phu dinh.
- So du, con lai va so ngay den cuoi chu ky phai lay tu summary/budget API hoac model local dong bo cung cong thuc; UI khong tu viet cong thuc khac.
- Khong xem khoan tien Split Bill phai thu la tien mat san sang chi tieu neu API khong danh dau no la kha dung.
- Neu thieu du lieu ngan sach, khong co so du hoac gia mon hang khong hop le, hien `Khong du du lieu de phan tich` thay vi doan.
- Ket qua chi la goi y tai chinh, khong tu tao giao dich va khong tu tru tien; nut hanh dong neu co phai quay ve form giao dich de nguoi dung xac nhan.

## 6. Local-first va trang thai du lieu

Moi man hinh co state ro rang:

- `initial`: chua co cache, hien skeleton ngan.
- `ready`: hien du lieu local.
- `syncing`: hien chi bao nho, khong khoa thao tac.
- `offline`: hien banner nho; van cho phep thao tac duoc luu local.
- `error`: hien loi, hanh dong retry va giu nguyen du lieu local.
- `empty`: giai thich ngan va mot hanh dong dau tien.

Quy tac:

- UI doc tu Riverpod provider cua local database, khong doc truc tiep tu widget.
- Thao tac ghi sinh UUID tren thiet bi, ghi drift truoc, sau do them sync queue.
- Khong hien cung mot ban ghi hai lan khi sync retry.
- Hien nhan pending khi ban ghi chua dong bo; nhan nay khong duoc lam thay doi kich thuoc item.
- Conflict phai co thong diep va cach xu ly; khong am tham ghi de len ban ghi cua nguoi dung.

## 7. Accessibility va quoc te hoa

- Moi icon button co semantic label; moi bieu do co mo ta text tom tat.
- Ho tro font scale lon cua Android den it nhat 200% ma khong cat mat so tien hoac nut chinh.
- Khong dat text trong kich thuoc co dinh; dung `Flexible`, `Expanded`, `Wrap` va scroll khi can.
- Kiem tra contrast theo WCAG AA cho text thuong va text lon.
- Ho tro Vietnamese truoc; tat ca chu hien thi di qua localization, khong hard-code trong widget.
- Dinh dang tien theo currency cua user va timezone cua user; khong noi cung VND/Asia Ho Chi Minh trong UI.
- Ngay, so tien va phan tram phai co semantics de TalkBack doc dung.

## 8. Hieu nang va vong doi

- Danh sach dai phai dung lazy builder, phan trang hoac query gioi han.
- Khong tinh tong, loc hoac sap xep lon trong `build()`.
- Khong goi API, database hoac tao subscription trong `build()`.
- Chart chi render khi man hinh hien thi; dispose controller/subscription dung cach.
- Anh hoa don co cache, thumbnail va kich thuoc gioi han.
- Muc tieu: mo Trang chu duoi 2 giay tren Android 4 GB khi da co cache; scroll khong giat.

## 9. Kiem thu giao dien

Bat buoc co:

- Widget test cho loading, empty, error, offline, pending va permission state.
- Golden/screenshot test cho Trang chu, form giao dich, Ngan sach, Thong ke, Muc tieu tiet kiem va Split Bill o kich thuoc dien thoai nho.
- Widget test cho AI Assistant va phan tich mua sam voi cac trang thai: loading, offline, het quota, thieu du lieu, ket qua dat va khong dat.
- Integration test cho: tao giao dich offline, retry sync, sua/xoa, filter, danh dau Split Bill da thanh toan, cap nhat muc tieu khong bi cong lap.
- Test accessibility voi font scale lon, TalkBack semantics va contrast.
- Test dark theme va man hinh xoay neu feature cho phep; du lieu khong mat khi xoay.

## 10. Tieu chi nghiem thu truoc khi merge

- Khong co overflow trong Flutter debug banner o cac kich thuoc dien thoai da chon.
- Khong co text bi cat, chong len nhau hoac nut nam ngoai tam voi.
- Moi trang thai cua provider da co UI tuong ung.
- UI khong tu tinh lai so lieu tai chinh bang cong thuc rieng.
- `flutter analyze`, `flutter test` va integration test lien quan deu dat.
- Diff chi cham vao pham vi feature; thay doi design token phai cap nhat tai lieu nay.
