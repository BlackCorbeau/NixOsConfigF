# Секреты (sops-nix)

Кратко: как всё устроено, как добавить новый секрет и как поднять рабочий sops на новом устройстве.

## Как устроено

- `.sops.yaml` в корне репозитория — список age-реципиентов и правила выбора ключа по пути файла.
- Секреты делятся на два уровня:
  - **host** (системные, читает root): зашифрованные файлы в `host/<Host>/secrets/<файл>`, метаданные в `host/<Host>/secrets/secrets.nix`, подключается из `host/<Host>/configuration.nix` через `imports`. При активации расшифровываются в `/run/secrets/<имя>`.
  - **user** (пользовательские, читает home-manager): один файл `user/<username>/secrets.yaml`, метаданные в `modules/user/secrets.nix`, подключается из `modules/user.nix` через `imports`. При активации расшифровываются в `~/.config/sops-nix/secrets/<имя>`.
- Расшифровка идёт в runtime, в `/nix/store` секреты не попадают.
- age-ключи выводятся из существующих SSH-ключей:
  - host — `/root/age.key` (читает root при активации),
  - user — `~/.config/sops/age/keys.txt` (читает пользователь при активации home-manager).

Текущие правила в `.sops.yaml`:

```yaml
keys:
  - &key age1tx6jdr6535xxeygpwkkgvdwc24tulr420cm7gk56xzfp0slzeqks2nwpyg

creation_rules:
  - path_regex: host/[^/]+/secrets/.+$
    key_groups:
      - age:
          - *key
  - path_regex: user/[^/]+/secrets\.yaml$
    key_groups:
      - age:
          - *key
```

Правило выбирается по пути файла. Важно: `path_regex` проверяется против пути **входного** файла относительно корня репозитория, поэтому открытое значение нужно создавать по целевому пути (см. примеры ниже).

## Host-секрет (системный)

### Добавить новый

1. Придумай имя, дальше для примера — `mysecret`.

2. Положи открытое значение во временный файл **внутри** `host/<Host>/secrets/` (путь важен — см. `path_regex`):

   ```bash
   printf '%s' 'СЕКРЕТНОЕ_ЗНАЧЕНИЕ' > host/ThinkPad/secrets/mysecret.plain
   ```

3. Зашифруй (приватный ключ не нужен — sops берёт публичного реципиента из `.sops.yaml`). Флаги указываются **до** позиционных аргументов:

   ```bash
   nix-shell -p sops --run \
     "sops --input-type binary --output-type binary \
        --encrypt --output host/ThinkPad/secrets/mysecret.enc \
        host/ThinkPad/secrets/mysecret.plain"
   rm host/ThinkPad/secrets/mysecret.plain
   ```

   `--input-type`/`--output-type` обязательны для бинарных данных, иначе sops пытается определить тип по расширению.

4. Опиши секрет в `host/<Host>/secrets/secrets.nix`:

   ```nix
   {
     sops = {
       age.keyFile = "/root/age.key";

       secrets = {
         mysecret = {
           format = "binary";        # yaml | json | binary | dotenv | ini
           sopsFile = ./mysecret.enc;
           owner = "kirill";          # владелец расшифрованного файла
           mode = "0400";
         };
       };
     };
   }
   ```

   `format = "binary"` — для произвольных байтов (`.pem`, токены). Для структурированных данных используй `yaml`/`json`.
   `owner`/`mode` нужны, если секрет читает пользовательский процесс (а не root-сервис).

5. `git add` — **Nix видит только файлы, добавленные в git** — и ребилд:

   ```bash
   git add host/ThinkPad/secrets/
   sudo nixos-rebuild switch --flake .#ThinkPad
   ```

6. Проверка:

   ```bash
   sudo ls -l /run/secrets/mysecret
   ```

### Изменить или посмотреть существующий секрет

Используется приватный ключ (`/root/age.key`), поэтому нужен root:

```bash
sudo SOPS_AGE_KEY_FILE=/root/age.key nix-shell -p sops --run \
  "sops --input-type binary --output-type binary host/ThinkPad/secrets/mysecret.enc"
```

`sops` сам не ищет `/root/age.key`, путь передаётся через `SOPS_AGE_KEY_FILE`.
Для бинарных файлов нужны `--input-type`/`--output-type`, иначе sops не сможет определить формат.

## User-секрет (home-manager)

Все пользовательские секреты лежат в одном файле `user/<username>/secrets.yaml`. Значения — вложенные ключи YAML, а имя секрета в nix-коде совпадает с путём этого ключа (`/` = вложенность). Например, секрет `tokens/apis/wallhaven` читается из:

```yaml
tokens:
  apis:
    wallhaven: ЗНАЧЕНИЕ
```

Путь расшифрованного файла: `~/.config/sops-nix/secrets/tokens/apis/wallhaven`.

### Добавить новый

1. Придумай имя, дальше для примера — `tokens/apis/wallhaven`.

2. Добавь значение в общий файл секретов (sops откроет расшифрованное содержимое в `$EDITOR` и зашифрует при сохранении; путь совпадает с `path_regex`, поэтому правило применится автоматически):

   ```bash
   nix-shell -p sops --run "sops user/kirill/secrets.yaml"
   ```

   Если файла ещё нет, создай его сразу по целевому пути и зашифруй на месте:

   ```bash
   printf 'tokens:\n  apis:\n    wallhaven: ЗНАЧЕНИЕ\n' > user/kirill/secrets.yaml
   nix-shell -p sops --run "sops --encrypt --in-place user/kirill/secrets.yaml"
   ```

3. Опиши секрет в `modules/user/secrets.nix`:

   ```nix
   { config, ... }: {
     sops = {
       defaultSopsFile = ../../user/${config.home.username}/secrets.yaml;
       age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

       secrets."tokens/apis/wallhaven" = {};
     };
   }
   ```

4. Используй в home-manager конфиге через путь:

   ```nix
   config.sops.secrets."tokens/apis/wallhaven".path
   ```

5. `git add` — **Nix видит только файлы, добавленные в git** — и ребилд:

   ```bash
   git add user/kirill/secrets.yaml modules/user/secrets.nix modules/user.nix
   sudo nixos-rebuild switch --flake .#ThinkPad
   ```

6. Проверка:

   ```bash
   ls -l ~/.config/sops-nix/secrets/tokens/apis/wallhaven
   ```

### Изменить или посмотреть существующий секрет

```bash
nix-shell -p sops --run "sops user/kirill/secrets.yaml"
```

sops подхватывает `~/.config/sops/age/keys.txt` автоматически. Если путь другой — задай `SOPS_AGE_KEY_FILE`.

## Новое устройство

1. Убедись, что на устройстве есть приватный SSH-ключ, из которого выводится age-ключ. Ключ должен быть **без пароля** — иначе расшифровка при активации будет требовать ввода. На текущей машине это `~/.ssh/id_ed25519_sops`.

2. Создай age-ключ хоста (root читает его при активации):

   ```bash
   sudo nix-shell -p ssh-to-age --run \
     "ssh-to-age -private-key -i /home/kirill/.ssh/id_ed25519_sops -o /root/age.key"
   sudo chmod 600 /root/age.key
   ```

3. Создай age-ключ пользователя (home-manager читает его при активации):

   ```bash
   mkdir -p ~/.config/sops/age
   nix-shell -p ssh-to-age --run \
     "ssh-to-age -private-key -i ~/.ssh/id_ed25519_sops -o ~/.config/sops/age/keys.txt"
   chmod 700 ~/.config/sops/age
   chmod 600 ~/.config/sops/age/keys.txt
   ```

4. Проверь, что публичный age-реципиент устройства совпадает с тем, что в `.sops.yaml`:

   ```bash
   nix-shell -p ssh-to-age --run \
     "ssh-to-age -i ~/.ssh/id_ed25519_sops.pub"
   ```

   Должно вывести:

   ```
   age1tx6jdr6535xxeygpwkkgvdwc24tulr420cm7gk56xzfp0slzeqks2nwpyg
   ```

   Если вывод другой — добавь новый реципиент (см. следующий раздел).

5. Создай структуру секретов хоста:

   ```
   host/<Host>/secrets/secrets.nix
   host/<Host>/secrets/<файлы секретов>
   ```

   Минимальный `secrets.nix`:

   ```nix
   {
     sops = {
       age.keyFile = "/root/age.key";
       secrets = { };
     };
   }
   ```

   И добавь `./secrets/secrets.nix` в `imports` в `host/<Host>/configuration.nix`.

6. Для пользовательских секретов создай `user/<username>/secrets.yaml` (см. раздел «User-секрет») и убедись, что `modules/user.nix` подключает `./user/secrets.nix`.

7. `git add` + ребилд:

   ```bash
   git add host/<Host>/secrets/ user/<username>/secrets.yaml modules/user/secrets.nix
   sudo nixos-rebuild switch --flake .#<Host>
   ```

## Добавить устройство к существующим секретам

1. Получи age-реципиент устройства (шаг 4 выше).

2. Добавь его в `.sops.yaml` в оба правила:

   ```yaml
   keys:
     - &key age1tx6jdr6535xxeygpwkkgvdwc24tulr420cm7gk56xzfp0slzeqks2nwpyg
     - &newdevice age1...новый_реципиент...           # замени на реальный

   creation_rules:
     - path_regex: host/[^/]+/secrets/.+$
       key_groups:
         - age:
             - *key
             - *newdevice
     - path_regex: user/[^/]+/secrets\.yaml$
       key_groups:
         - age:
             - *key
             - *newdevice
   ```

3. Перешифруй существующие секреты под новый список реципиентов (нужен приватный ключ). Для host-секретов — root и `/root/age.key`:

   ```bash
   sudo SOPS_AGE_KEY_FILE=/root/age.key nix-shell -p sops --run \
     "sops updatekeys host/ThinkPad/secrets/mysecret.enc"
   ```

   Для user-секретов — пользовательский ключ:

   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt nix-shell -p sops --run \
     "sops updatekeys user/kirill/secrets.yaml"
   ```

4. `git add` + ребилд на этом устройстве.
