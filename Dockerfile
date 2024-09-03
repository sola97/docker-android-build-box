# 使用Ubuntu作为基础镜像
FROM ubuntu:20.04

# 设置环境变量以避免 tzdata 配置交互提示
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 安装时区数据包，设置时区并安装其他依赖项
RUN apt-get update && apt-get install -y \
    tzdata curl git unzip openjdk-11-jdk \
    && ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo Asia/Shanghai > /etc/timezone

# 安装 Android SDK 和构建工具
RUN mkdir -p /opt/android-sdk/cmdline-tools \
    && cd /opt/android-sdk/cmdline-tools \
    && curl -o commandlinetools-linux.zip https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip \
    && unzip commandlinetools-linux.zip -d latest && rm commandlinetools-linux.zip \
    && mv latest/cmdline-tools/* latest/ && rm -rf latest/cmdline-tools \
    && yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android-sdk --licenses \
    && /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android-sdk "platform-tools" "build-tools;34.0.0" "platforms;android-33"

# 配置环境变量
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0

# 验证安装
RUN java -version \
    && /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android-sdk --list

CMD ["/bin/bash"]
