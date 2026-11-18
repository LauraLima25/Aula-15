# Catálogo de veículos

Aplicação Flutter para cadastrar, consultar, editar e excluir veículos.
Para testes locais, o acesso usa o usuário de exemplo `aluno` e a senha
de exemplo `123456`. Não utilize essas credenciais em produção.

## Como funciona

- `aplicativo_flutter`: interface Flutter.
- `backend_dart`: API em Dart que recebe as operações e salva os
  veículos em SQLite.
- `iniciar.bat`: prepara as dependências e inicia a API e o aplicativo no Windows.

O banco `backend_dart\veiculos.db` é criado automaticamente na
primeira execução. Os dados permanecem salvos ao fechar o aplicativo e a API.
Após o login, a API fornece um token que deve acompanhar as requisições ao
catálogo. O token dura 30 minutos e deixa de valer quando o servidor reinicia.

## Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/install/manual) com Dart 3.13.5 ou
  superior, antes da versão 4. Adicione a pasta `bin` do Flutter ao `Path` ou
  defina `FLUTTER_ROOT` com o caminho da pasta do SDK.
- Google Chrome para executar no navegador.
- Para Android: Android SDK, JDK 17 e um emulador ou dispositivo conectado com
  depuração USB. Execute `flutter doctor` e, se necessário,
  `flutter doctor --android-licenses`.

## Executar no Windows

Abra um terminal na pasta que contém `iniciar.bat`:

```bat
iniciar.bat
```

O comando baixa as dependências, inicia a API e abre a aplicação no Chrome.
Mantenha as duas janelas abertas durante o uso. A porta 8080 deve estar livre.

Para executar em um dispositivo Android conectado:

```bat
iniciar.bat android
```

Se houver mais de um dispositivo, informe seu identificador mostrado por
`flutter devices`: `iniciar.bat android SERIAL`. O iniciador configura
`adb reverse` para permitir que o aplicativo acesse a API no computador.

## Executar manualmente

Em um terminal, inicie a API:

```text
cd backend_dart
dart pub get
dart run bin/servidor.dart
```

Em outro terminal, inicie a interface no Chrome:

```text
cd aplicativo_flutter
flutter pub get
flutter run -d chrome
```

Para testar a interface, execute `flutter test` dentro de
`aplicativo_flutter`. Para Android, o modo de depuração usa HTTP local;
em um emulador ou celular conectado por USB, execute
`adb reverse tcp:8080 tcp:8080` antes de `flutter run -d android`.
