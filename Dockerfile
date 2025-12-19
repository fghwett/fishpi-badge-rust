# 多阶段构建 Dockerfile for fishpi-badge-rust
# 支持多架构: linux/amd64, linux/arm64

# ============ 依赖规划阶段 ============
FROM rust:1.91.0-slim AS chef
RUN cargo install cargo-chef
WORKDIR /app

# ============ 依赖分析阶段 ============
FROM chef AS planner
COPY Cargo.toml ./
COPY src ./src
RUN cargo chef prepare --recipe-path recipe.json

# ============ 构建阶段 ============
FROM chef AS builder

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    binutils \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制依赖配方并构建依赖（这一层会被缓存）
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json

# 复制源代码并构建应用
COPY Cargo.toml ./
COPY src ./src
RUN cargo build --release && \
    strip target/release/fishpi-badge-rust

# ============ 运行阶段 ============
FROM gcr.io/distroless/cc-debian12

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/target/release/fishpi-badge-rust /app/fishpi-badge-rust

# 复制静态资源和模板
COPY static ./static
COPY templates ./templates

# 暴露端口
EXPOSE 3001

# 设置默认环境变量
ENV RUST_LOG=info

# 启动应用（distroless 默认使用 nonroot 用户）
CMD ["/app/fishpi-badge-rust"]
