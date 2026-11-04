# A2DP-подключение вместо служебного RFCOMM: 04.11.2026

## Подтверждённый сбой после предыдущего исправления

13:30–13:32: программа открывала raw RFCOMM Hands-Free, получала fConnected,
но примерно через 6 секунд соединение падало. Целевой waveOut отсутствовал.
Восстановление transport-only соединения ждало 20 секунд и не успевало
сработать. Открытый RFCOMM без HFP service-level handshake не является
подключением аудиопрофиля; точная причина шестисекундного разрыва без
трассы HCI/RFCOMM не установлена.

## Новый основной путь

- Core Audio перечисляет render endpoints ACTIVE | UNPLUGGED, не включая
  пользовательские DISABLED и NOTPRESENT.
- Через DeviceTopology / GetDeviceIdConnectedTo определяется adapter identity.
- Выбор требует одновременно адрес целевого устройства и профиль A2DP sink
  `{0000110b-0000-1000-8000-00805f9b34fb}`. Friendly name не используется
  как идентификатор.
- IKsControl целевого адаптера получает KSPROPSETID_BtAudio,
  KSPROPERTY_ONESHOT_RECONNECT (GET, NULL value).
- Повтор каждые 10 секунд до target streaming; clock сохраняется при
  коротких transport-only соединениях и сбрасывается при resume/стабильном audio.
- При принятом native запросе raw HFP paging и destructive driver/radio
  recovery не конкурируют с драйвером. Если native запрос недоступен или
  завершился ошибкой, остаётся прежний ограниченный fallback.
- Успешный HRESULT означает только принятую попытку, не готовность звука.
  Отдельный keepalive подтверждает постановку буфера в целевой waveOut.

Источник контракта: Microsoft Learn, KSPROPERTY_ONESHOT_RECONNECT и
Using the IKsControl Interface to Access Audio Properties; ABI/GUID проверены
по локальному Windows SDK 10.0.26100.0.

## Проверка

- 81 root test и 92 PoC tests прошли; release build успешен.
- Установлена `rust3.0-a2dp-reconnect` по прежнему пути задачи Bluetooth Force;
  ровно один экземпляр, hash совпал с проверенной сборкой.
- Backup: `.sharrowkin/backups/bluetooth_force-before-a2dp-reconnect-20261104.exe`.
- Первая 50-секундная проверка НЕ прошла: native запросы приняты, но наушники
  не подключились. Наличие включённых наушников тогда не было подтверждено.
- Пользователь затем сообщил: «Сейчас вынул из кейса»; ручное подключение
  не запрашивалось. 13:41:44 link UP, 13:41:45 target waveOut/48 kHz stereo,
  13:41:47 audio READY. 13:42:13 snapshot: Bluetooth connected, Redmi waveOut
  присутствует; после audio READY разрывов не было. Индексы waveOut изменились,
  поэтому приёмка проверяет имя устройства, не фиксированный индекс #2.
- Пользователь подтвердил: «Да, звук в наушниках» при обычном воспроизведении.
- Повторные циклы кейса и пробуждение ПК после сна этой проверкой не покрыты.

Запуск bounded runtime проверки:
`python .sharrowkin/scripts/test_a2dp_runtime.py`.
Она не воспроизводит тестовый звук и не подтверждает слышимость без пользователя.
