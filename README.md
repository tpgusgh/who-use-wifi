# Who Use Wifi

집 안 서버들이 어느 포트에 뭘 띄워놨는지 한눈에 보여주는 macOS 앱.
같은 서브넷을 스캔해서 열린 포트와 웹 서비스 배너/타이틀을 보여준다.

설계 문서: [docs/spec.md](docs/spec.md)

## 빌드

```bash
swift build -c release
./scripts/build_dmg.sh
```

## 테스트

```bash
swift test
```
