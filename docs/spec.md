# Who Use Wifi — 설계 문서

집 안 같은 서브넷에 떠있는 서버들이 어느 포트를 열어놨는지(웹/백엔드 등)
한눈에 보여주는 macOS 앱.

## 목표

- 맥이 붙어있는 로컬 네트워크(같은 서브넷)를 스캔해서
- 열려있는 포트를 가진 호스트를 찾고
- 웹 서비스라면 배너/타이틀까지 보여줘서
- "이 IP 저 포트에 뭐가 떠있더라" 를 매번 기억 안 해도 되게 함

## 비목표

- 전체 포트(1-65535) 스캔, 취약점 스캔, 지속적 모니터링/알림은 하지 않음
- 결과를 디스크에 저장하지 않음 (매 스캔마다 새로 조회)

## 아키텍처

- SwiftUI 네이티브 macOS 앱, `macOS 13+`
- Swift Package Manager 기반 executable target (Xcode 프로젝트 파일 없이
  `swift build` 로 빌드 가능) → 빌드 스크립트가 `.app` 번들로 포장 후 `.dmg` 생성
- Swift Concurrency(`async/await`, `TaskGroup`)로 스캔 병렬 처리

## 핵심 로직

1. **서브넷 감지**: `getifaddrs()` 로 활성 네트워크 인터페이스의 IPv4 주소 +
   넷마스크를 읽어서 `/24` 대역을 계산 (예: `192.168.0.0/24` → `.1` ~ `.254`)
2. **포트 스캔**: 호스트 x 주요 포트 조합마다 `NWConnection` 으로 TCP connect
   시도. 동시성은 세마포어로 최대 64개 제한.
   - 주요 포트 목록(상수 배열로 관리):
     `80, 443, 3000, 3001, 3306, 5000, 5432, 6379, 7000, 8000, 8008,
     8080, 8081, 8443, 8888, 9000, 9090, 9200, 27017`
3. **배너 조회**: 포트가 열려있으면 `http://ip:port` 로 짧은 타임아웃(1~2초)
   HTTP GET 시도 → `Server` 헤더와 `<title>` 태그 추출. 실패하면 "포트 열림"만 표시.
4. 결과는 메모리에만 보관.

## 데이터 모델

```swift
struct HostResult: Identifiable {
    let id: String            // IP
    var ports: [PortResult]
}

struct PortResult: Identifiable {
    let id: Int                // port number
    var banner: String?        // Server 헤더
    var title: String?         // <title>
    var pid: Int32?            // 로컬 머신 프로세스일 때만
    var processName: String?   // 로컬 머신 프로세스일 때만
}
```

## 내 맥(로컬 머신) 처리

- 원격 호스트는 고정 포트 목록만 TCP 커넥트로 훑지만, 내 맥 자신은 `lsof -iTCP
  -sTCP:LISTEN -P -n` 로 실제 리스닝 중인 포트 전부(개발 서버가 흔히 쓰는
  임의 포트 포함)와 프로세스명/PID를 정확히 가져옴
- 이 호스트만 UI에서 "이 기기"로 표시하고, 포트별로 "종료" 버튼 제공
  (확인창 → `kill(pid, SIGTERM)`). 원격 서버는 종료 불가(같은 컴퓨터가
  아니므로 범위 밖)

## UI

- 상단: "스캔" 버튼 + 진행 상태(몇 호스트째 / 전체)
- 본문: IP별로 접었다 펼 수 있는 그룹 리스트
  - 각 포트 줄: 포트 번호 + 배너/타이틀 텍스트 + "브라우저로 열기" 버튼
  - 내 기기 포트 줄은 프로세스명/PID 표시 + "종료" 버튼(확인 후 SIGTERM)

## 권한 / 배포

- macOS 로컬 네트워크 접근 권한 팝업 발생 → `Info.plist` 에
  `NSLocalNetworkUsageDescription` 필요
- 코드사이닝/공증 없는 무료 배포용 `.dmg`. 최초 실행 시 Gatekeeper 경고 →
  우클릭 후 "열기" 필요

## 테스트

- 서브넷 계산 로직, 포트 필터링 로직 유닛 테스트 (`swift test`)
- 나머지는 실제 홈 네트워크에서 수동 확인
