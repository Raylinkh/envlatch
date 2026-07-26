import Security

public enum CodeIdentity {
    public static func currentDesignatedRequirement() -> String {
        let flags = SecCSFlags(rawValue: 0)
        var code: SecCode?
        let selfStatus = SecCodeCopySelf(flags, &code)
        guard selfStatus == errSecSuccess, let code else {
            return "unavailable:SecCodeCopySelf:\(selfStatus)"
        }

        var staticCode: SecStaticCode?
        let staticStatus = SecCodeCopyStaticCode(code, flags, &staticCode)
        guard staticStatus == errSecSuccess, let staticCode else {
            return "unavailable:SecCodeCopyStaticCode:\(staticStatus)"
        }

        var requirement: SecRequirement?
        let requirementStatus = SecCodeCopyDesignatedRequirement(staticCode, flags, &requirement)
        guard requirementStatus == errSecSuccess, let requirement else {
            return "unavailable:SecCodeCopyDesignatedRequirement:\(requirementStatus)"
        }

        var text: CFString?
        let textStatus = SecRequirementCopyString(requirement, flags, &text)
        guard textStatus == errSecSuccess, let text else {
            return "unavailable:SecRequirementCopyString:\(textStatus)"
        }
        return text as String
    }
}
