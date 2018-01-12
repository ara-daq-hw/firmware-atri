--
-- This is a helper VHDL module to enable assertions in
-- Verilog. 
-- It has (a < b), (a > b), (a != b)

entity vassert_if_less_than is
  
  generic (
    VALUE : in Integer;
    LIMIT : in Integer;
    ERR  : in string;
	 WARN : in string := "NO"
    );
end vassert_if_less_than;

entity vassert_if_greater_than is
  
  generic (
    VALUE : in Integer;
    LIMIT : in Integer;
    ERR  : in string;
	 WARN : in string := "NO"
    );
end vassert_if_greater_than;

entity vassert_if_not is
  
  generic (
    BOOL : in boolean;
    ERR  : in string;
	 WARN : in string := "NO"
    );
end vassert_if_not;

architecture a_vassert_if_less_than of vassert_if_less_than is

begin  -- a_vassert_if_less_than

  A_WARN: if (WARN="YES") generate
	assert VALUE < LIMIT report ERR severity warning;
  end generate A_WARN;
  A_FAIL: if (WARN="NO") generate
	assert VALUE < LIMIT report ERR severity failure;
  end generate A_FAIL;
end a_vassert_if_less_than;

architecture a_vassert_if_greater_than of vassert_if_greater_than is

begin  -- a_vassert_if_greater_than

  A_WARN: if (WARN="YES") generate
	assert VALUE > LIMIT report ERR severity warning;
  end generate A_WARN;
  A_FAIL: if (WARN="NO") generate
	assert VALUE > LIMIT report ERR severity failure;
  end generate A_FAIL;

end a_vassert_if_greater_than;

architecture a_vassert_if_not of vassert_if_not is

begin  -- a_vassert_if_not

  A_WARN: if (WARN="YES") generate
	assert not BOOL report ERR severity warning;
  end generate A_WARN;

  A_FAIL: if (WARN="NO") generate
	assert not BOOL report ERR severity failure;
  end generate A_FAIL;


end a_vassert_if_not;
