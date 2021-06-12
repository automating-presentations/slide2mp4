FROM fedora:34
LABEL maintainer="Hirofumi Kojima"
# podman build -t slide2mp4:latest <PATH_OF_DOCKERFILE>


RUN dnf -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-34.noarch.rpm
RUN dnf -y install awscli ffmpeg ghostscript git google-noto-sans*-cjk-jp-fonts GraphicsMagick python3 libxml2
RUN dnf -y update
RUN dnf clean all


RUN git clone --depth 1 https://github.com/h-kojima/slide2mp4
RUN cp slide2mp4/slide2mp4.sh /usr/local/bin/slide2mp4
RUN cp slide2mp4/tools/chapters-timestamp.sh /usr/local/bin/chapters-timestamp
RUN cp slide2mp4/tools/lexicon-generate.sh /usr/local/bin/lexicon-generate
RUN cp slide2mp4/tools/lexicon2dic.sh /usr/local/bin/lexicon2dic
RUN chmod +x /usr/local/bin/*
RUN rm -rf slide2mp4

