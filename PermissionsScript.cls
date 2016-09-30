Map<String, String> OLD_TO_NEW_PERMISSIONS =
	new Map<String, String>{
		'Document_Manager_Approved_Permissions' => 'Document_Manager_Edit_After_Approval',
		'Document_Manager_Edit_Permissions' => 'Document_Manager_Edit_Loan_Details',
		'Document_Manager_Empty_Staging_Area_Permissions' => 'Document_Manager_Delete_Loan_Files'
	};
String DM_REVIEWER_ROLE_PERMISSION = 'Document_Manager_Review_Loan_Documents';

List<PermissionSetAssignment> permissionsToInsert = new List<PermissionSetAssignment>();
Map<String, Id> universalPermissionSets = new Map<String, Id>();
List<PermissionSet> permissions = [
	SELECT
		Id,
		Name
	FROM
		PermissionSet
	WHERE
		Name IN :OLD_TO_NEW_PERMISSIONS.values()
	OR
		Name = :DM_REVIEWER_ROLE_PERMISSION
];
Map<String, Id> permissionSetNames = new Map<String, Id>();
if(permissions != null && permissions.size() > 0){
	for(PermissionSet p : permissions){
		universalPermissionSets.put(p.Name, p.Id);
	}
}
List<User> activeUsers = [
	SELECT
		Id,
	(SELECT
		AssigneeId,
		PermissionSet.Name
	FROM
		PermissionSetAssignments
	WHERE
		PermissionSet.Name IN :OLD_TO_NEW_PERMISSIONS.keySet()
	OR
		PermissionSet.Name IN :OLD_TO_NEW_PERMISSIONS.values())
	FROM
		User
	WHERE
		IsActive = true
];
Set<String> universalPermissions = new Set<String>();
for(String perm : OLD_TO_NEW_PERMISSIONS.values()){
	universalPermissions.add(perm);
}
if(activeUsers != null && activeUsers.size() > 0){
	for(Integer i = 0; i < activeUsers.size(); i++){
		for(PermissionSetAssignment assignment : activeUsers[i].PermissionSetAssignments){
			if(universalPermissions.contains(assignment.PermissionSet.Name)){
				activeUsers.remove(i);
			}
		}
	}
}

for(User u : activeUsers){
	for(PermissionSetAssignment permission : u.PermissionSetAssignments){
		String universalPermission =
			OLD_TO_NEW_PERMISSIONS.get(permission.PermissionSet.Name);
		permissionsToInsert.add(
			new PermissionSetAssignment(
				AssigneeId = u.Id,
				PermissionSetId = universalPermissionSets.get(universalPermission)
			)
		);
	}
}


//DM_ReviewerRoles Permission
Set<String> uniqueRoles = new Set<String>();
List<LLC_BI__CFG_ConfigValue__c> reviewerValue = [
	SELECT
		Id,
		LLC_BI__FieldValue__c
	FROM
		LLC_BI__CFG_ConfigValue__c
	WHERE
	LLC_BI__Category__c = 'Document Manager'
	AND
	LLC_BI__Key__c = 'DM_ReviewerRoles'
];
if(reviewerValue != null &&
	reviewerValue.size() > 0 &&
	reviewerValue[0].LLC_BI__FieldValue__c != null){
	List<String> roles = reviewerValue[0].LLC_BI__FieldValue__c.split(',');
	for(String role : roles){
		uniqueRoles.add(role);
	}
}
List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
List<UserRole> userRoleIds = [
	SELECT
		Id,
		Name
	FROM
		UserRole
	WHERE
	Name != null
	AND
	Name IN :uniqueRoles
];
if(userRoleIds != null && userRoleIds.size() > 0) {
	List<User> usersToAssignPermission = [
		SELECT
			Id
		FROM
			User
		WHERE
		UserRoleId IN :userRoleIds
		AND
		Id NOT IN (
			SELECT
				AssigneeId
			FROM
				PermissionSetAssignment
			WHERE
				PermissionSet.Name = :DM_REVIEWER_ROLE_PERMISSION
		)
		AND
			IsActive = true
	];
	if (usersToAssignPermission != null && usersToAssignPermission.size() > 0) {
		List<PermissionSet> reviewPermission = [
			SELECT
				Id
			FROM
				PermissionSet
			WHERE
				Name = :DM_REVIEWER_ROLE_PERMISSION
		];
		if (reviewPermission != null && reviewPermission.size() > 0) {
			for (User u : usersToAssignPermission) {
				permissionsToInsert.add(
					new PermissionSetAssignment(
						AssigneeId = u.Id,
						PermissionSetId = reviewPermission[0].Id
					)
				);
			}
		}
	}
}
insert permissionsToInsert;
