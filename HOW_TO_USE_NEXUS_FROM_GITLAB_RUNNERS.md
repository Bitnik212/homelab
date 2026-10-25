# How to point GitLab runners at Nexus

Makes every Java (Maven / Gradle) CI job on a runner VM pull dependencies
through Nexus (`vm-nexus`, `salt/nexus`) at `https://nexus.bitt.app` instead
of straight from Maven Central. Everything here is done on the runner VM
itself. Neither the projects' `.gitlab-ci.yml` / `pom.xml` / `build.gradle`
nor this repo needs to change.

`nexus.bitt.app` has a real TLS certificate, served from `10.20.10.4`. The
runner VM pins the name to that address with a hosts record, so traffic
stays on the LAN instead of going out to the public DNS record. HTTPS also
means none of Maven's / Gradle's "insecure HTTP repository" exceptions are
needed.

Repeat for each runner VM.

## Prerequisite: the runner can reach 10.20.10.4

```sh
curl -sS -o /dev/null -w '%{http_code}\n' \
  --resolve nexus.bitt.app:443:10.20.10.4 \
  https://nexus.bitt.app/repository/maven-public/junit/junit/4.13.2/junit-4.13.2.pom
```

Expect `200`. If it times out, the VM has no path to the LAN. A VM that's
**only** on hashibr (`10.30.30.0/24`) can't reach `10.20.10.0/24`:
router-1 doesn't NAT hashibr->LAN, and the LAN has no route back (see
`salt/router/nat.sls`). Give it a second NIC on vmbr0 the way
vm-curseforge / vm-nexus have one (`proxmox-terraform/curseforge.tf`,
`salt/curseforge/network.sls`), then re-check.

## 1. Hosts record on the runner VM

For anything run directly on the VM, and for shell-executor jobs:

```sh
echo '10.20.10.4 nexus.bitt.app' | sudo tee -a /etc/hosts
getent hosts nexus.bitt.app   # -> 10.20.10.4 nexus.bitt.app
```

Docker-executor job containers **don't** inherit the VM's `/etc/hosts`.
They get the same pin via `extra_hosts` in step 4.

## 2. Maven settings file

`/etc/gitlab-runner/nexus/settings.xml`:

```xml
<settings>
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>https://nexus.bitt.app/repository/maven-public/</url>
    </mirror>
  </mirrors>
</settings>
```

`mirrorOf *` sends every repository a build asks for through Nexus.
`maven-public` is Nexus's default group, which currently wraps
`maven-central`.

## 3. Gradle init script

`/etc/gitlab-runner/nexus/nexus.gradle`:

```groovy
def nexus = 'https://nexus.bitt.app/repository/maven-public/'

settingsEvaluated { settings ->
    settings.pluginManagement.repositories {
        maven { url nexus }
        gradlePluginPortal()
    }
}

allprojects {
    buildscript.repositories.clear()
    buildscript.repositories { maven { url nexus } }
    repositories.clear()
    repositories { maven { url nexus } }
}
```

- `gradlePluginPortal()` stays as a fallback. Nexus has no proxy for
  `plugins.gradle.org` (yet), so plugins that aren't on Maven Central
  still come from there directly.
- The `.clear()` calls also remove any private repositories a project
  declares itself. If some project has those, delete the two `.clear()`
  lines and Nexus is just added in front instead.

```sh
sudo mkdir -p /etc/gitlab-runner/nexus
# write the two files above, then:
sudo chmod 0644 /etc/gitlab-runner/nexus/*
```

## 4. `/etc/gitlab-runner/config.toml` (Docker executor)

Add to **each** `[[runners]]` block that runs Java jobs, keeping whatever's
already in `environment` / `volumes` / `extra_hosts`:

```toml
[[runners]]
  # ...existing settings...
  environment = [
    "MAVEN_ARGS=--settings /nexus/settings.xml",
  ]
  [runners.docker]
    # ...existing settings...
    extra_hosts = ["nexus.bitt.app:10.20.10.4"]
    volumes = [
      "/cache",   # keep existing entries
      "/etc/gitlab-runner/nexus/settings.xml:/nexus/settings.xml:ro",
      "/etc/gitlab-runner/nexus/nexus.gradle:/root/.gradle/init.d/nexus.gradle:ro",
    ]
```

- **Maven:** 3.9+ reads `MAVEN_ARGS` on every `mvn` / `./mvnw` call. For
  images with older Maven, also mount the file at `/root/.m2/settings.xml`.
- **Gradle:** reads every script in `~/.gradle/init.d/` on its own. Two
  cases need adjusting:
  - A job that sets `GRADLE_USER_HOME` (common for CI caching, e.g.
    `$CI_PROJECT_DIR/.gradle`) makes Gradle look for `init.d/` there
    instead, so `/root/.gradle/init.d` is skipped.
  - An image that doesn't run as root has a different home than `/root`.

  In either case, change the mount target to match.

The runner reloads `config.toml` on its own when the file changes. To be
sure: `sudo gitlab-runner restart`.

### Shell executor instead

There's no container, so skip step 4 and drop the files into the
`gitlab-runner` user's home. The hosts record from step 1 already covers
it.

```sh
sudo -u gitlab-runner mkdir -p ~gitlab-runner/.m2 ~gitlab-runner/.gradle/init.d
sudo cp /etc/gitlab-runner/nexus/settings.xml ~gitlab-runner/.m2/settings.xml
sudo cp /etc/gitlab-runner/nexus/nexus.gradle ~gitlab-runner/.gradle/init.d/nexus.gradle
sudo chown -R gitlab-runner: ~gitlab-runner/.m2 ~gitlab-runner/.gradle
```

## 5. Verify

Run any Java pipeline, then check:

- **Maven job log:** downloads come from
  `https://nexus.bitt.app/repository/maven-public/...`, not
  `repo.maven.apache.org`. A job step running `mvn help:effective-settings`
  shows the `nexus` mirror.
- **Gradle:** with `--info`, the log shows the init script being applied
  and dependencies resolving from `nexus.bitt.app`.
- **Nexus UI** (`https://nexus.bitt.app`, browse `maven-central`): the
  build's components show up.
- **Cache:** fetching the same artifact twice shows
  `X-Cache-Status: HIT` the second time. That's nginx's cache on vm-nexus
  answering without touching Nexus.

  ```sh
  curl -sI https://nexus.bitt.app/repository/maven-public/junit/junit/4.13.2/junit-4.13.2.pom | grep -i x-cache
  ```

## Not covered

Docker images the jobs pull still come from Docker Hub directly, since
there's no Docker proxy repo in Nexus yet. Same for Gradle plugins that
are only on `plugins.gradle.org`.
