FROM python:3.10-slim as base

# Install Build Dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    curl \
    wget \
    build-essential


# Application User
ENV APP_USER_ID=1000
ENV APP_GROUP_ID=1000
ENV SRC_PATH=/usr/src/

RUN groupadd app --gid ${APP_GROUP_ID} && \
    useradd --uid ${APP_USER_ID} --gid ${APP_GROUP_ID} -m -s /bin/bash app

# Python Environment Variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100

# Poetry Environment Variables
ENV POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1 \
    POETRY_VERSION=1.1.6

# Set our paths so commands are available
ENV PATH="$POETRY_HOME/bin:$SRC_PATH/.venv/bin:$PATH"

# Copy berglas binary
RUN wget https://storage.googleapis.com/berglas/0.6.2/linux_amd64/berglas -O /bin/berglas
RUN chmod +x /bin/berglas
WORKDIR ${SRC_PATH}

FROM base as builder

# Install Poetry - Usese POETRY_HOME and POETRY_VERSION natively
RUN curl -sSL https://install.python-poetry.org | python

COPY ./poetry.lock* ./pyproject.toml ${SRC_PATH}
RUN poetry install --no-dev
COPY . ${SRC_PATH}

FROM base as production

COPY --from=builder ${SRC_PATH}.venv ${SRC_PATH}.venv
COPY . ${SRC_PATH}

CMD /bin/berglas exec -- gunicorn --chdir src/ app.asgi \
        -k uvicorn.workers.UvicornWorker \
        --workers=${GUNICORN_WORKERS:-1} \
        --threads=${GUNICORN_THREADS:-8} \
        --timeout=${GUNICORN_TIMEOUT:-0} \
        --bind=0.0.0.0:8000
