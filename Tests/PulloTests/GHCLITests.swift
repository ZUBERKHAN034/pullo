@testable import Pullo
import Testing

struct GHCLITests {
    @Test func readsEveryAccountOfTheHost() {
        let hosts = """
        github.com:
            git_protocol: ssh
            users:
                ana-acme:
                jordan-cod:
                    oauth_token: gho_secret
            user: jordan-cod
        ghe.company.com:
            users:
                someone-else:
        """
        #expect(GHCLI.users(inHostsFile: hosts, host: "github.com") == ["ana-acme", "jordan-cod"])
        #expect(GHCLI.users(inHostsFile: hosts, host: "ghe.company.com") == ["someone-else"])
    }

    @Test func noUsersSection() {
        #expect(GHCLI.users(inHostsFile: "github.com:\n    user: jordan-cod\n", host: "github.com").isEmpty)
    }
}
