# 🎓 Personal Assistant — учебный проект для практики Docker

Простое FastAPI-приложение, которое используется как основа для лабораторной работы по Docker.

# Лабораторная работа № 3 — Персистентность и изоляция контейнеров

## Индивидуальные параметры

| Параметр | Значение |
|---|---|
| Номер ИСУ | `466519` |
| Префикс контейнеров | `lishchuk` |
| Порт приложения | `8019` |
| Порт PostgreSQL | `5449` |
| Секретный ключ приложения | `secret19lishchuk` |
| Имя базы данных | `lishchuk19` |

## 1. Подготовка PostgreSQL и приложения

Для начала создадим именованный Docker volume. 

```bash
docker volume create lishchuk-pgdata

docker volume inspect lishchuk-pgdata
```

Запустим PostgreSQL с подключённым хранилищем:

```bash
docker run -d \
  --name lishchuk-postgres \
  -e POSTGRES_USER=user_19 \
  -e POSTGRES_PASSWORD=pgpass_19 \
  -e POSTGRES_DB=assistant_19\
  -v lishchuk-pgdata:/var/lib/postgresql/data \
  -p 5449:5432 \
  postgres:15
```

Проверим, что контейнер запущен:

```bash
docker ps --filter "name=lishchuk-postgres" \
  --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Теперь соберём образ приложения:

```bash
docker build -t lishchuk-assistant:v3 .
```

Посмотрим, появился ли образ в локальном хранилище Docker:

```bash
docker images | grep lishchuk-assistant
```

Запустим приложение. На этом этапе подключение к базе выполняется через `host.docker.internal`, который позволяет контейнеру обратиться к хостовой машине.

```bash
docker run -d \
  --name lishchuk-assistant \
  --add-host=host.docker.internal:host-gateway \
  -p 8019:8019 \
  -e APP_OWNER=lishchuk \
  -e APP_SECRET=<blank> \
  -e DATABASE_URL="postgresql://<blank>:<blank>@host.docker.internal:5449/<blank>" \
  lishchuk-assistant:v3
```

Проверим состояние контейнера:

```bash
docker ps --filter "name=lishchuk-assistant" \
  --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Проверка API

Получим ответ главной страницы:

```bash
curl http://localhost:8019/
echo
```

Проверим состояние подключения к базе данных:

```bash
curl http://localhost:8019/health
echo
```

Создадим тестовую заметку:

```bash
curl -X POST http://localhost:8019/notes \
  -H "Content-Type: application/json" \
  -d '{"text": "ЛР3: проверка сохранения данных"}'
echo
```

Получим список заметок:

```bash
curl http://localhost:8019/notes
echo
```

## 2. Проверка сохранности данных

Проверим, сохраняются ли записи после удаления контейнера приложения.

Остановим и удалим контейнер assistant:

```bash
docker stop lishchuk-assistant
docker rm lishchuk-assistant
```


```bash
docker run -d \
  --name lishchuk-assistant \
  --add-host=host.docker.internal:host-gateway \
  -p 8019:8019 \
  -e APP_OWNER=lishchuk \
  -e APP_SECRET=secret19lishchuk \
  -e DATABASE_URL="postgresql://user_19:pgpass_19@host.docker.internal:5449/assistant_19" \
  lishchuk-assistant:v3
```

Убедимся, что приложение запущено:

```bash
docker ps --filter "name=lishchuk" \
  --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Запросим ранее созданные заметки:

```bash
curl http://localhost:8019/notes
echo
```

Сформируем артефакт для фиксации результата:

```bash
echo "========================================" && \
echo "Тест персистентности: $(date '+%H:%M:%S')" && \
echo "$(whoami)@$(hostname)" && \
echo "========================================" && \
curl -s http://localhost:8019/notes | python3 -m json.tool
```

## 3. Подключение конфигурации через bind mount


Посмотрим текущую конфигурацию:

```bash
cat config/app.conf
```

Остановим прежний контейнер приложения:

```bash
docker stop lishchuk-assistant
docker rm lishchuk-assistant
```

Создадим новый контейнер с подключённым каталогом `config`:

```bash
docker run -d \
  --name lishchuk-assistant-config \
  --add-host=host.docker.internal:host-gateway \
  -p 8019:8019 \
  -e APP_OWNER=lishchuk \
  -e APP_SECRET=secret19lishchuk \
  -e DATABASE_URL="postgresql://user_19:pgpass_19@host.docker.internal:5449/assistant_19" \
  -v "$(pwd)/config:/app/config:ro" \
  lishchuk-assistant:v3
```

Параметр `:ro` запрещает контейнеру изменять файлы подключённого каталога.

Проверим состояние контейнера:

```bash
docker ps --filter "name=lishchuk-assistant-config"
```

Посмотрим конфигурационный файл изнутри контейнера:

```bash
docker exec -it lishchuk-assistant-config sh
```

Внутри контейнера выполним:

```bash
cat /app/config/app.conf
```

Для выхода из оболочки:

```bash
exit
```

## 4. Изоляция контейнеров с помощью пользовательской сети

Создадим сеть:

```bash
docker network create lishchuk-backend
```

Проверим её наличие:

```bash
docker network ls --filter "name=lishchuk"
```

Удалим предыдущие контейнеры приложения и базы данных, если они ещё существуют:

```bash
docker stop lishchuk-assistant-config
docker rm lishchuk-assistant-config

docker stop lishchuk-postgres lishchuk-assistant
docker rm lishchuk-postgres lishchuk-assistant
```

### Запуск PostgreSQL в пользовательской сети

```bash
docker run -d \
  --name lishchuk-postgres \
  --network lishchuk-backend \
  -p 5449:5432 \
  -e POSTGRES_USER=user_19 \
  -e POSTGRES_PASSWORD=pgpass_19 \
  -e POSTGRES_DB=assistant_19 \
  -v lishchuk-pgdata:/var/lib/postgresql/data \
  postgres:15
```

### Запуск приложения в той же сети

```bash
docker run -d \
  --name lishchuk-assistant \
  --network lishchuk-backend \
  -p 8019:8019 \
  -e APP_OWNER=lishchuk \
  -e APP_SECRET=secret19lishchuk \
  -e DATABASE_URL="postgresql://user_19:pgpass_19@host.docker.internal:5449/assistant_19"\
  -v "$(pwd)/config:/app/config:ro" \
  lishchuk-assistant:v3
```


Проверим, что оба контейнера работают:

```bash
docker ps --filter "name=lishchuk" \
  --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Проверим API:

```bash
curl http://localhost:8019/health
echo
```

Создадим новую заметку:

```bash
curl -X POST http://localhost:8019/notes \
  -H "Content-Type: application/json" \
  -d '{"text": "ЛР3: проверка пользовательской сети"}'
echo
```

Получим список записей:

```bash
curl http://localhost:8019/notes
echo
```

### Проверка сетевой изоляции

Запустим временный контейнер Alpine вне пользовательской сети:

```bash
docker run -it --rm alpine:3.18 ping -c 2 lishchuk-postgres
```

Затем выполним аналогичную команду внутри пользовательской сети:

```bash
docker run -it --rm \
  --network lishchuk-backend \
  alpine:3.18 ping -c 2 lishchuk-postgres
```

В пользовательской сети Docker разрешает имя контейнера `lishchuk-postgres` через встроенный DNS. Вне этой сети такое имя обычно не разрешается.

## 5. Финальный артефакт
```bash
echo "========================================" && \
echo "ЛР3 завершена: $(date '+%d.%m.%Y %H:%M:%S')" && \
echo "Студент: $(whoami)@$(hostname)" && \
echo "========================================" && \
echo "" && \
echo "Контейнеры:" && \
docker ps --filter "name=lishchuk-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" && \
echo "" && \
echo "Volumes:" && \
docker volume ls --filter "name=lishchuk-" && \
echo "" && \
echo "Сети:" && \
docker network ls --filter "name=lishchuk-"
```


## 📁 Структура проекта

```
simple_example/
├── app/
│   ├── __init__.py
│   ├── main.py          # FastAPI + маршруты
│   ├── database.py      # Подключение к PostgreSQL
│   ├── models.py        # Модель Note (SQLAlchemy)
│   └── crud.py          # CRUD операции
├── config/
│   └── app.conf         # Конфиг для bind mount (челлендж)
├── requirements.txt     # Python-зависимости
└── README.md
```

## 💻 Локальный запуск (без Docker)

### 1. Установить зависимости

```bash
cd simple_example
pip install -r requirements.txt
```

### 2. Задать переменные окружения

**macOS / Linux:**

```bash
export APP_OWNER=ВашеИмя
export APP_SECRET=ваш_секретный_ключ
export DATABASE_URL=ваш урл
```

**Windows (PowerShell):**

```powershell
$env:APP_OWNER="ВашеИмя"
$env:APP_SECRET="ваш_секретный_ключ"
$env:DATABASE_URL="postgresql://postgres"
```

**Windows (CMD):**

```cmd
set APP_OWNER=ВашеИмя
set APP_SECRET=ваш_секретный_ключ
set DATABASE_URL=postgresql://postgres:postgres@localhost:5432/assistant_db
```

> Если не задать переменные, приложение запустится со значениями по умолчанию.
> Для работы заметок необходима запущенная PostgreSQL (см. ниже).

### 3. Запустить сервер

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Флаг `--reload` автоматически перезапускает сервер при изменении кода.

### 4. Открыть в браузере

- Приложение: **http://localhost:8000**
- Swagger UI: **http://localhost:8000/docs**

## 📡 Эндпоинты

| Метод | URL | Описание |
|-------|-----|----------|
| GET | `/` | Главная страница — приветствие и список эндпоинтов |
| GET | `/health` | Healthcheck — статус приложения |
| GET | `/docs` | Swagger UI — интерактивная документация (встроена в FastAPI) |
| GET | `/me` | Информация о владельце (из переменных окружения) |
| GET | `/secret/{key}` | Проверка секретного ключа — убедитесь, что `APP_SECRET` пробрасывается |
| GET | `/weather/{city}` | Текущая погода в городе через Open-Meteo API |
| POST | `/notes` | Создать заметку в БД (тело: `{"text": "..."}`) |
| GET | `/notes` | Получить все заметки текущего владельца |
| GET | `/notes/{id}` | Получить заметку по ID |
| DELETE | `/notes/{id}` | Удалить заметку по ID |

### Примеры запросов

```bash
# Главная
curl http://localhost:8000/

# Погода в Москве
curl http://localhost:8000/weather/Moscow

# Проверка секретного ключа
curl http://localhost:8000/secret/ваш_секретный_ключ

# Создать заметку (сохраняется в PostgreSQL)
curl -X POST http://localhost:8000/notes \
  -H "Content-Type: application/json" \
  -d '{"text": "Моя первая заметка"}'

# Получить заметки текущего владельца
curl http://localhost:8000/notes

# Получить заметку по ID
curl http://localhost:8000/notes/1

# Удалить заметку
curl -X DELETE http://localhost:8000/notes/1
```

## 🔑 Переменные окружения

| Переменная | Описание | Значение по умолчанию |
|------------|----------|-----------------------|
| `APP_OWNER` | Имя владельца приложения | `anonymous` |
| `APP_SECRET` | Секретный ключ для эндпоинта `/secret/{key}` | `default_secret` |
| `DATABASE_URL` | Строка подключения к PostgreSQL | `postgresql://postgres:postgres@localhost:5432/assistant_db` |


## 🗄 PostgreSQL (для эндпоинтов /notes)

Заметки хранятся в PostgreSQL. Для локальной разработки проще всего запустить БД через Docker:

```bash
docker run -d \
  --name assistant-db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=assistant_db \
  -p 5432:5432 \
  postgres:16-alpine
```

Таблица `notes` создаётся автоматически при старте приложения (`Base.metadata.create_all`).

### Файл config/app.conf

В папке `config/` лежит файл `app.conf` — пример конфигурации для **bind mount** в лабораторной работе 4. Студент может монтировать этот файл в контейнер и использовать значения из него.

## 🌤 API погоды — важно для пользователей из РФ

Эндпоинт `/weather/{city}` обращается к открытому API **[Open-Meteo](https://open-meteo.com/)** (бесплатный, без ключа):

1. **Геокодинг** — `geocoding-api.open-meteo.com` — получает координаты города
2. **Прогноз** — `api.open-meteo.com` — получает текущую погоду по координатам

### ⚠️ Блокировки РКН

Домены `open-meteo.com` могут быть недоступны из российских сетей из-за блокировок РКН.

Если эндпоинт `/weather/{city}` возвращает ошибку таймаута — **необходимо использовать средства обхода блокировок:**

- **VPN** — включите VPN на машине, где запущен Docker

## ✅ Как проверить, что всё работает

1. `curl http://localhost:8000/` — должен вернуть приветствие с вашим именем
2. `curl http://localhost:8000/me` — должен показать `secret_prefix` (первые 6 символов вашего ключа)
3. `curl http://localhost:8000/secret/ваш_ключ` — должен вернуть `LAB2_SUCCESS_ВАШЕИМЯ`
4. `curl http://localhost:8000/weather/London` — должен вернуть температуру, влажность, ветер
5. `docker inspect --format='{{.State.Health.Status}}' personal-assistant` — должен вернуть `healthy`

