#--
#   Copyright (C) 2003, 2004 Matt Armstrong.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
# NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

def distdir_post_dist_hook
  unless system("ruby1.6 tests/runtests.rb")
    fail "ruby 1.6 failed tests"
  end
  unless system("ruby-1.8.1 tests/runtests.rb")
    fail "ruby-1.8.1 failed tests"
  end
  unless FileTest.directory?("doc") and
      FileTest.exist?("doc/index.html")
    fail "docs don't exist"
  end
  # FIXME: run an HTML link checker on the docs here...
end

def tarball_hook(tarball_name)

  www_dir = '/home/website/public_html/rubymail'
  download_dir = File.join(www_dir, 'download')
  if FileTest.directory?(download_dir)
    tarball_basename = File.basename(tarball_name)
    File.copy(tarball_name, File.join(download_dir, tarball_basename))
    Dir.chdir(www_dir) {
      unless system("gzip -d < download/#{tarball_basename} | tar xf -")
        fail "can't untar in web dir"
      end
      package_dir = "#{package}-#{version}"
      File.cleandir(package)
      File.rename(package_dir, package)
    }
  end
end
