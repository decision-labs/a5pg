FROM rust:1.89-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    lsb-release \
    build-essential \
    libssl-dev \
    pkg-config \
    git \
    && rm -rf /var/lib/apt/lists/*

# Add PostgreSQL APT repository (modern approach without apt-key)
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

# Install PostgreSQL 15, 16, and 17 with dev packages
RUN apt-get update && apt-get install -y \
    postgresql-15 \
    postgresql-server-dev-15 \
    postgresql-16 \
    postgresql-server-dev-16 \
    postgresql-17 \
    postgresql-server-dev-17 \
    && rm -rf /var/lib/apt/lists/*

# Install cargo-pgrx with sccache for faster compilation
RUN cargo install sccache --locked && \
    RUSTC_WRAPPER=sccache cargo install cargo-pgrx --locked && \
    rm -rf /usr/local/cargo/registry/cache && \
    rm -rf /usr/local/cargo/git/db && \
    rm -rf /root/.cargo/registry/cache

# Set up pgrx with all Postgres versions
RUN cargo pgrx init \
    --pg15 /usr/lib/postgresql/15/bin/pg_config \
    --pg16 /usr/lib/postgresql/16/bin/pg_config \
    --pg17 /usr/lib/postgresql/17/bin/pg_config

# Set permissions for extension directories
RUN chmod -R a+w /usr/share/postgresql/15/extension && \
    chmod -R a+w /usr/lib/postgresql/15/lib && \
    chmod -R a+w /usr/share/postgresql/16/extension && \
    chmod -R a+w /usr/lib/postgresql/16/lib && \
    chmod -R a+w /usr/share/postgresql/17/extension && \
    chmod -R a+w /usr/lib/postgresql/17/lib

# Create non-root user for running tests (initdb requires non-root)
RUN useradd -m -s /bin/bash pgrxuser && \
    mkdir -p /home/pgrxuser/.pgrx /home/pgrxuser/.cargo && \
    cp -r /root/.pgrx/* /home/pgrxuser/.pgrx/ && \
    chown -R pgrxuser:pgrxuser /home/pgrxuser && \
    chown -R pgrxuser:pgrxuser /usr/local/cargo

USER pgrxuser
WORKDIR /workspace

# Configure cargo to use sccache for faster compilation
# Note: CARGO_INCREMENTAL must be 0 when using sccache
ENV RUSTC_WRAPPER=sccache \
    SCCACHE_DIR=/home/pgrxuser/.cache/sccache \
    CARGO_INCREMENTAL=0 \
    CARGO_NET_GIT_FETCH_WITH_CLI=true

# Copy Cargo files first for better caching
COPY --chown=pgrxuser:pgrxuser Cargo.toml Cargo.lock ./

# Create dummy source to cache dependencies
RUN mkdir -p src && \
    echo "fn main() {}" > src/lib.rs && \
    cargo build --no-default-features --features pg17 || true && \
    rm -rf src target/debug/deps/a5pg* && \
    sccache --show-stats

# Copy the actual source
COPY --chown=pgrxuser:pgrxuser . .

CMD ["/bin/bash"]
