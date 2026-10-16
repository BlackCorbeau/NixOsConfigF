# Секреты (sops-nix)

Кратко: как всё устроено, как добавить новый секрет и как поднять рабочий sops на новом устройстве.

## Как устроено

- `.sops.yaml` в корне репозитория — список age-реципиентов и правила выбора ключа по пути файла.
- Зашифрованные секреты хоста: `host/<Host>/secrets/<файл>`.
- Метаданные секретов: `host/<Host>/secrets/secrets.nix`, подключается из `host/<Host>/configuration.nix` через `imports`.
- При активации sops-nix расшифровывает секреты в `/run/secrets/<имя>` (runtime, в `/nix/store` ничего не попадает).
- age-ключ выводится из существующего SSH-ключа.

Текущее правило в `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: host/[^/]+/secrets/.+$
```

То есть правило выбирается по пути файла: всё, что лежит в `host/<Host>/secrets/`, шифруется на перечисленных реципиентов.

## Добавить новый секрет

1. Придумай имя, дальше для примера — `mysecret`.

2. Положи открытое значение во временный файл **внутри** `host/<Host>/secrets/` (путь важен — см. `path_regex`):

   ```bash
   printf '%s' 'СЕКРЕТНОЕ_ЗНАЧЕНИЕ' > host/ThinkPad/secrets/mysecret.plain
   ```

3. Зашифруй (приватный ключ не нужен — sops берёт публичного реципиента из `.sops.yaml`):

   ```bash
   nix-shell -p sops --run \
     "sops --input-type binary --output-type binary \
        --encrypt host/ThinkPad/secrets/mysecret.plain \
        --output host/ThinkPad/secrets/mysecret.enc"
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

## Изменить или посмотреть существующий секрет

Используется приватный ключ (`/root/age.key`), поэтому нужен root:

```bash
sudo SOPS_AGE_KEY_FILE=/root/age.key nix-shell -p sops --run \
  "sops host/ThinkPad/secrets/wallhaven.pem"
```

`sops` сам не ищет `/root/age.key`, путь передаётся через `SOPS_AGE_KEY_FILE`.

## Новое устройство

1. Убедись, что на устройстве есть приватный SSH-ключ, из которого выводится age-ключ. Ключ должен быть **без пароля** — иначе расшифровка при активации будет требовать ввода.

2. Создай age-ключ:

   ```bash
   sudo nix-shell -p ssh-to-age --run \
     "ssh-to-age -private-key -i /home/kirill/.ssh/<ваш_ключ> -o /root/age.key"
   sudo chmod 600 /root/age.key
   ```

3. Проверь, что публичный age-реципиент устройства совпадает с тем, что в `.sops.yaml`:

   ```bash
   nix-shell -p ssh-to-age --run \
     "ssh-to-age -i /home/kirill/.ssh/<ваш_ключ>.pub"
   ```

   Должно вывести:

   ```
   age1tx6jdr6535xxeygpwkkgvdwc24tulr420cm7gk56xzfp0slzeqks2nwpyg
   ```

   Если вывод другой — добавь новый реципиент (см. следующий раздел).

4. Создай структуру секретов хоста:

   ```
   host/<Host>/secrets/secrets.nix
   host/<Host>/secrets/<файлы секретов>
   ```

   Минимальный `secrets.nix`:

   ```nix
   {
     sops.age.keyFile = "/root/age.key";
     secrets = {
       # ...
     };
   }
   ```

   И добавь `./secrets/secrets.nix` в `imports` в `host/<Host>/configuration.nix`.

5. `git add` + ребилд:

   ```bash
   git add host/<Host>/secrets/
   sudo nixos-rebuild switch --flake .#<Host>
   ```

## Добавить устройство к существующим секретам

1. Получи age-реципиент устройства (шаг 3 выше).

2. Добавь его в `.sops.yaml`:

   ```yaml
   keys:
     - &kirill age1tx6jdr6535xxeygpwkkgvdwc24tulr420cm7gk56xzfp0slzeqks2nwpyg
     - &newdevice age1...новый_реципиент...           # замени на реальный

   creation_rules:
     - path_regex: host/[^/]+/secrets/.+$
       key_groups:
         - age:
             - *kirill
             - *newdevice
   ```

3. Перешифруй существующие секреты под новый список реципиентов (нужен приватный ключ, значит root):

   ```bash
   sudo SOPS_AGE_KEY_FILE=/root/age.key nix-shell -p sops --run \
     "sops updatekeys host/ThinkPad/secrets/wallhaven.pem"
   ```

4. `git add` + ребилд на этом устройстве.
