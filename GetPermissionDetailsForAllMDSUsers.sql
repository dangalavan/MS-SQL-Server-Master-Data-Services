

	-- Author : Dan Galavan
	-- Date: 19-November-2013
	-- Description:	Get full listing of user permissions in MDS 
	-- Notes: 1. Reconfigure the "Get Model ID" section by replacing the "Enter Model Name here" text 
	--		  with the the relevant model name 
	-- 	  2. This is based on undocumented Master Data database objects which are subject to change with future releases. 
	-- Disclaimer: Use this script at your own risk.


	SET NOCOUNT ON

	DECLARE @SystemUser_ID				INT  -- currently logged on user
			, @Principal_ID				INT  
			, @PrincipalType_ID			INT  
			, @IncludeGroupAssignments	BIT = 1
			, @Model_ID					INT = NULL  
			, @DisplayName				VARCHAR(512)
			, @Logon					VARCHAR(512)

	
	
	DECLARE @Permissions TABLE (RoleAccess_ID		INT
								,RoleAccess_MUID	uniqueIdentifier
								,Privlege_ID		INT
								,Privledge_Name		VARCHAR(255)
								,Object_Type_ID		INT
								,Object_Type_Name	VARCHAR(255)
								,Securable_ID		INT
								,Securable_MUID		uniqueIdentifier
								,Securable_Name		VARCHAR(255)
								,Model_ID			INT
								,Model_MUID			uniqueIdentifier
								,Model_Name			VARCHAR(255)
								,SourceUserGroup_ID		INT
								,SourceUserGroup_MUID	uniqueIdentifier
								,SourceUserGroup_Name	VARCHAR(255)	
								,IsAdministrator		INT
								,DisplayName			VARCHAR(512)
								,Logon					VARCHAR(512)								
								)
	
	
	-- Get user ID based on current logon. 
		SET @SystemUser_ID = (select ID
						from mdm.tblUser t
						where t.UserName = SUSER_SNAME())
					
	-- Get Model ID
		SET @Model_ID = (SELECT TOP 1 V.Model_ID
							from mdm.viw_SYSTEM_SCHEMA_VERSION V
							WHERE V.Model_Name = 'Enter Model Name here'
								AND V.[Status] = 'Open')		-- configure status as required..
													
	-- time to start checking permissions..
		DECLARE curs_MDS_Users CURSOR FAST_FORWARD FOR SELECT A.Principal_ID			
															,A.PrincipalType_ID	
															,U.DisplayName
															,A.[Description]	AS Logon

													FROM mdm.tblSecurityAccessControl	A WITH (NOLOCK)
													INNER JOIN mdm.tblUser				U  WITH (NOLOCK) ON U.ID =  A.Principal_ID												
		OPEN curs_MDS_Users 
		FETCH NEXT FROM curs_MDS_Users INTO @Principal_ID, @PrincipalType_ID , @DisplayName, @Logon
		WHILE @@FETCH_STATUS = 0
			BEGIN 
		
				INSERT INTO @Permissions
							(
							RoleAccess_ID	
							,RoleAccess_MUID
							,Privlege_ID	
							,Privledge_Name	
							,Object_Type_ID	
							,Object_Type_Name
							,Securable_ID	
							,Securable_MUID	
							,Securable_Name	
							,Model_ID		
							,Model_MUID		
							,Model_Name		
							,SourceUserGroup_ID	
							,SourceUserGroup_MUID
							,SourceUserGroup_Name
							,IsAdministrator
							)
				EXEC mdm.udpSecurityPrivilegesSummaryGet @SystemUser_ID
														,@Principal_ID
														,@PrincipalType_ID
														,@IncludeGroupAssignments
														,@Model_ID
				
				-- Add Logon and display name to result set
					UPDATE @Permissions 
						SET Logon		 =	@Logon
							,DisplayName =	@DisplayName
					WHERE Logon IS NULL AND DisplayName IS NULL
														
				FETCH NEXT FROM curs_MDS_Users INTO @Principal_ID, @PrincipalType_ID, @DisplayName, @Logon
			END

		CLOSE curs_MDS_Users 
		DEALLOCATE curs_MDS_Users 
		
		
		SELECT P.DisplayName
				,P.Logon
				,P.Securable_Name
				,P.Privledge_Name
		FROM @Permissions	P
		WHERE P.Object_Type_Name = 'Entity'
			AND P.Privledge_Name <> 'DenyAccess'	-- use predicate to get what permissions you require
		

		PRINT 'Permissions identified.'	