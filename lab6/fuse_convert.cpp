#define FUSE_USE_VERSION 31


#include <fuse3/fuse.h>

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <algorithm>

#include <dirent.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <unistd.h>


static std::string g_original_dir;


static std::string full_path(const char *path)
{
    return g_original_dir + path;
}

static bool ends_with_ci(const std::string &str, const std::string &suffix)
{
    if (str.size() < suffix.size()) return false;
    std::string tail = str.substr(str.size() - suffix.size());
    std::transform(tail.begin(), tail.end(), tail.begin(), ::tolower);
    std::string suf = suffix;
    std::transform(suf.begin(), suf.end(), suf.begin(), ::tolower);
    return tail == suf;
}

static bool is_jpg_name(const std::string &name)
{
    return ends_with_ci(name, ".jpg") || ends_with_ci(name, ".jpeg");
}


static std::string jpg_to_png_path(const std::string &jpg)
{
    if (ends_with_ci(jpg, ".jpeg"))
        return jpg.substr(0, jpg.size() - 5) + ".png";
    if (ends_with_ci(jpg, ".jpg"))
        return jpg.substr(0, jpg.size() - 4) + ".png";
    return {};
}


static int convert_png_to_jpg_tmp(const std::string &png_path)
{
    char tmpl[] = "/tmp/fuse_convert_XXXXXX";
    int tmp_fd = mkstemp(tmpl);
    if (tmp_fd == -1) return -errno;
    close(tmp_fd);

    std::string cmd = std::string("convert '") + png_path + "' 'jpeg:" + tmpl + "' 2>/dev/null";

    if (system(cmd.c_str()) != 0) {
        unlink(tmpl);
        return -EIO;
    }

    int fd = open(tmpl, O_RDONLY);
    if (fd == -1) {
        int saved = errno;
        unlink(tmpl);
        return -saved;
    }
    unlink(tmpl);
    return fd;
}

static int fc_getattr(const char *path, struct stat *st,
                      struct fuse_file_info * /*fi*/)
{
    std::string fpath = full_path(path);

    if (lstat(fpath.c_str(), st) == 0) return 0;
    int saved = errno;

    if (saved == ENOENT && is_jpg_name(fpath)) {
        std::string png = jpg_to_png_path(fpath);
        struct stat png_st;
        if (!png.empty() && lstat(png.c_str(), &png_st) == 0
            && S_ISREG(png_st.st_mode))
        {
            int fd = convert_png_to_jpg_tmp(png);
            if (fd >= 0) {
                struct stat tmp_st;
                if (fstat(fd, &tmp_st) == 0) {
                    *st = png_st;
                    st->st_size   = tmp_st.st_size;
                    st->st_blocks = tmp_st.st_blocks;
                    close(fd);
                    return 0;
                }
                close(fd);
            }
            *st = png_st;
            return 0;
        }
    }
    return -saved;
}

static int fc_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                      off_t, struct fuse_file_info *,
                      enum fuse_readdir_flags)
{
    std::string fpath = full_path(path);

    DIR *dp = opendir(fpath.c_str());
    if (!dp) return -errno;

    std::vector<std::string> pngs, real_jpgs;

    struct dirent *de;
    while ((de = readdir(dp)) != nullptr) {
        struct stat st{};
        st.st_ino  = de->d_ino;
        st.st_mode = de->d_type << 12;

        if (filler(buf, de->d_name, &st, 0, static_cast<fuse_fill_dir_flags>(0))) break;

        if (de->d_type != DT_REG && de->d_type != DT_UNKNOWN) continue;

        std::string name(de->d_name);
        if (ends_with_ci(name, ".png"))
            pngs.push_back(name.substr(0, name.size() - 4));
        else if (ends_with_ci(name, ".jpeg"))
            real_jpgs.push_back(name.substr(0, name.size() - 5));
        else if (ends_with_ci(name, ".jpg"))
            real_jpgs.push_back(name.substr(0, name.size() - 4));
    }
    closedir(dp);

    for (const auto &base : pngs) {
        bool has_real = std::find(real_jpgs.begin(), real_jpgs.end(), base)
                        != real_jpgs.end();
        if (!has_real) {
            struct stat st{};
            st.st_mode = S_IFREG | 0644;
            filler(buf, (base + ".jpg").c_str(), &st, 0, static_cast<fuse_fill_dir_flags>(0));
        }
    }
    return 0;
}

static int fc_open(const char *path, struct fuse_file_info *fi)
{
    std::string fpath = full_path(path);

    int fd = open(fpath.c_str(), fi->flags);
    if (fd != -1) { fi->fh = fd; return 0; }
    int saved = errno;

    if (saved == ENOENT && is_jpg_name(fpath)
        && (fi->flags & O_ACCMODE) == O_RDONLY)
    {
        std::string png = jpg_to_png_path(fpath);
        if (!png.empty() && access(png.c_str(), F_OK) == 0) {
            int conv_fd = convert_png_to_jpg_tmp(png);
            if (conv_fd >= 0) { fi->fh = conv_fd; return 0; }
            return conv_fd;
        }
    }
    return -saved;
}

static int fc_read(const char *, char *buf, size_t size,
                   off_t offset, struct fuse_file_info *fi)
{
    ssize_t n = pread(fi->fh, buf, size, offset);
    return n == -1 ? -errno : static_cast<int>(n);
}

static int fc_write(const char *, const char *buf, size_t size,
                    off_t offset, struct fuse_file_info *fi)
{
    ssize_t n = pwrite(fi->fh, buf, size, offset);
    return n == -1 ? -errno : static_cast<int>(n);
}

static int fc_release(const char *, struct fuse_file_info *fi)
{
    close(fi->fh);
    return 0;
}

static int fc_create(const char *path, mode_t mode, struct fuse_file_info *fi)
{
    std::string fpath = full_path(path);
    int fd = open(fpath.c_str(), fi->flags | O_CREAT, mode);
    if (fd == -1) return -errno;
    fi->fh = fd;
    return 0;
}

static int fc_unlink(const char *path)
{
    return unlink(full_path(path).c_str()) == -1 ? -errno : 0;
}

static int fc_mkdir(const char *path, mode_t mode)
{
    return mkdir(full_path(path).c_str(), mode) == -1 ? -errno : 0;
}

static int fc_rmdir(const char *path)
{
    return rmdir(full_path(path).c_str()) == -1 ? -errno : 0;
}

static int fc_rename(const char *from, const char *to, unsigned int flags)
{
    if (flags) return -EINVAL;
    return rename(full_path(from).c_str(), full_path(to).c_str()) == -1
           ? -errno : 0;
}

static int fc_chmod(const char *path, mode_t mode, struct fuse_file_info * /*fi*/)
{
    return chmod(full_path(path).c_str(), mode) == -1 ? -errno : 0;
}

static int fc_chown(const char *path, uid_t uid, gid_t gid,
                    struct fuse_file_info * /*fi*/)
{
    return lchown(full_path(path).c_str(), uid, gid) == -1 ? -errno : 0;
}

static int fc_truncate(const char *path, off_t size, struct fuse_file_info *fi)
{
    if (fi) return ftruncate(fi->fh, size) == -1 ? -errno : 0;
    return truncate(full_path(path).c_str(), size) == -1 ? -errno : 0;
}

static int fc_utimens(const char *path, const struct timespec ts[2],
                      struct fuse_file_info * /*fi*/)
{
    return utimensat(AT_FDCWD, full_path(path).c_str(), ts,
                     AT_SYMLINK_NOFOLLOW) == -1 ? -errno : 0;
}

static int fc_statfs(const char *path, struct statvfs *st)
{
    return statvfs(full_path(path).c_str(), st) == -1 ? -errno : 0;
}

static int fc_readlink(const char *path, char *buf, size_t size)
{
    ssize_t n = readlink(full_path(path).c_str(), buf, size - 1);
    if (n == -1) return -errno;
    buf[n] = '\0';
    return 0;
}

static int fc_symlink(const char *target, const char *link_path)
{
    return symlink(target, full_path(link_path).c_str()) == -1 ? -errno : 0;
}

static int fc_link(const char *from, const char *to)
{
    return link(full_path(from).c_str(), full_path(to).c_str()) == -1
           ? -errno : 0;
}

static int fc_access(const char *path, int mask)
{
    std::string fpath = full_path(path);
    if (access(fpath.c_str(), mask) == 0) return 0;
    int saved = errno;

    if (saved == ENOENT && is_jpg_name(fpath)) {
        std::string png = jpg_to_png_path(fpath);
        if (!png.empty() && access(png.c_str(), mask & ~W_OK) == 0)
            return 0;
    }
    return -saved;
}


static const fuse_operations fc_ops = [] {
    fuse_operations ops{};
    ops.getattr  = fc_getattr;
    ops.readdir  = fc_readdir;
    ops.open     = fc_open;
    ops.read     = fc_read;
    ops.write    = fc_write;
    ops.release  = fc_release;
    ops.create   = fc_create;
    ops.unlink   = fc_unlink;
    ops.mkdir    = fc_mkdir;
    ops.rmdir    = fc_rmdir;
    ops.rename   = fc_rename;
    ops.chmod    = fc_chmod;
    ops.chown    = fc_chown;
    ops.truncate = fc_truncate;
    ops.utimens  = fc_utimens;
    ops.statfs   = fc_statfs;
    ops.readlink = fc_readlink;
    ops.symlink  = fc_symlink;
    ops.link     = fc_link;
    ops.access   = fc_access;
    return ops;
}();


int main(int argc, char *argv[])
{
    if (argc < 3) {
        fprintf(stderr,
            "Usage: %s <original_dir> <mount_point> [fuse_options...]\n"
            "Example:\n"
            "  %s ./original_dir ./mounted_dir -f\n",
            argv[0], argv[0]);
        return 1;
    }

    char *resolved = realpath(argv[1], nullptr);
    if (!resolved) {
        fprintf(stderr, "Cannot resolve '%s': %s\n", argv[1], strerror(errno));
        return 1;
    }
    g_original_dir = resolved;
    free(resolved);

    struct stat st;
    if (stat(g_original_dir.c_str(), &st) != 0 || !S_ISDIR(st.st_mode)) {
        fprintf(stderr, "'%s' is not a directory\n", g_original_dir.c_str());
        return 1;
    }

    std::vector<char *> new_argv;
    new_argv.push_back(argv[0]);
    for (int i = 2; i < argc; i++)
        new_argv.push_back(argv[i]);
    new_argv.push_back(nullptr);

    return fuse_main(static_cast<int>(new_argv.size()) - 1,
                     new_argv.data(), &fc_ops, nullptr);
}
