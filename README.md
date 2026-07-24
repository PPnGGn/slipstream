# v2net

Руководства по закуску

## Общие требования

Репозитории:

- Xray wrapper (core): [https://github.com/PPnGGn/v2net-core.git](https://github.com/PPnGGn/v2net-core.git)
- Flutter client: [https://github.com/PPnGGn/v2net.git](https://github.com/PPnGGn/v2net.git)


### Предварительная настройка

Установить `gomobile`

```
go install golang.org/x/mobile/cmd/gomobile@latest
```

Убедиться, что `$(go env GOPATH)/bin` есть в `PATH`:

```
export PATH="$PATH:$(go env GOPATH)/bin"
```

```
gomobile init
```

Клонирование репозиториев (выполнить в корневой папке `vpn/`):

```
git clone https://github.com/PPnGGn/v2net.git
git clone https://github.com/PPnGGn/v2net-core.git
```

Структура папок:

```
vpn/
  v2net/
  v2net-core/
```

## Инструкция для Android

Сборка ядра:

```
cd v2net
make build-core-android
```

Проверка: `android/app/libs/v2netcore.aar`

---



## Инструкция для iOS

Сборка ядра:

```
cd v2net
make build-core-ios
```

Проверка: `ios/Frameworks/v2netcore.xcframework` 

## Запуск Flutter:

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
make generate-vpn-api
flutter run
```



