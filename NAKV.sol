// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ERC20 temel implementasyonu
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

abstract contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    
    // Token holder yönetimi için değişkenleri buraya ekliyoruz
    mapping(address => bool) private _isTokenHolder;
    address[] private _tokenHolders;
    
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
    
    function name() public view virtual returns (string memory) {
        return _name;
    }
    
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view virtual returns (uint8) {
        return 18;
    }
    
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        
        emit Transfer(from, to, amount);
        
        _afterTokenTransfer(from, to, amount);
    }
    
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        
        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
        
        _afterTokenTransfer(address(0), account, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
    
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 /* amount */
    ) internal virtual {
        // Yeni token holder'ı ekle
        if (to != address(0) && !_isTokenHolder[to] && balanceOf(to) > 0) {
            _isTokenHolder[to] = true;
            _tokenHolders.push(to);
        }
        
        // Eğer gönderen kişinin token'ı kalmadıysa listeden çıkar
        if (from != address(0) && balanceOf(from) == 0) {
            _isTokenHolder[from] = false;
            _removeTokenHolder(from);
        }
    }
    
    function _removeTokenHolder(address holder) private {
        for (uint256 i = 0; i < _tokenHolders.length; i++) {
            if (_tokenHolders[i] == holder) {
                _tokenHolders[i] = _tokenHolders[_tokenHolders.length - 1];
                _tokenHolders.pop();
                break;
            }
        }
    }
    
    function _getTokenHolders() internal view returns (address[] memory) {
        return _tokenHolders;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }
    
    modifier onlyOwner() {
        _checkOwner();
        _;
    }
    
    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }
    
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract NakamotoFallacyMint is ERC20, Ownable {
    uint256 public constant INITIAL_OWNER_ALLOCATION = 10_000 * 10**18;
    uint256 public constant PHASE_WALLET_COUNT = 100_000;
    uint256 public constant BLOCKS_LOOKBACK = 1_000_000;
    uint256 public constant MIN_GAS_SPENT = 11 * 10**8; // 1.1 nAVAX (1.1 * 10^9 wei)

    uint256 public totalMintedWallets;
    uint256 public totalReflected;
    mapping(address => bool) public hasMinted;
    mapping(address => uint256) public lastMintBlock;
    
    event TokensMinted(address indexed wallet, uint256 amount, uint256 reflectedAmount);
    event ReflectionDistributed(uint256 amount);
    
    constructor() ERC20("Nakamoto Fallacy Mint", "NAKV") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_OWNER_ALLOCATION);
    }
    
    function getCurrentMintAmount() public view returns (uint256) {
        uint256 currentPhase = 0;
        uint256 walletLimit = PHASE_WALLET_COUNT; // 100_000 başlangıç
        
        // Hangi fazda olduğumuzu hesapla
        while (totalMintedWallets >= walletLimit && walletLimit <= type(uint256).max / 2) {
            currentPhase++;
            walletLimit *= 2; // Her fazda limit 2 katına çıkar
        }
        
        // Başlangıç miktarı 1 token (10^18), her fazda yarıya iner
        return 1 * 10**18 / (2**currentPhase);
    }
    
    function isEligibleForMint(address wallet) public view returns (bool) {
        if (hasMinted[wallet]) {
            return false;
        }
        
        uint256 gasSpent = 0;
        // Bu kısımda gerçek implementasyonda, cüzdanın gas harcamasını 
        // kontrol etmek için harici bir oracle veya veri kaynağı kullanılmalıdır
        // Örnek amaçlı basit bir kontrol yapılmıştır
        gasSpent = wallet.balance > 0 ? MIN_GAS_SPENT : 0;
        
        return gasSpent >= MIN_GAS_SPENT;
    }
    
    function getCurrentReflectionRate() public view returns (uint256) {
        uint256 currentPhase = 0;
        uint256 walletLimit = PHASE_WALLET_COUNT;
        
        while (totalMintedWallets >= walletLimit && walletLimit <= type(uint256).max / 2) {
            currentPhase++;
            walletLimit *= 2;
        }
        
        // Başlangıç reflection oranı %50, her fazda yarıya iner
        return 50 / (2**currentPhase);
    }
    
    function _distributeReflection(uint256 amount) internal {
        uint256 totalSupplyBeforeReflection = totalSupply();
        if (totalSupplyBeforeReflection == 0) return;
        
        // Her token sahibinin payını hesapla ve dağıt
        uint256 reflectionPerToken = (amount * 10**18) / totalSupplyBeforeReflection;
        
        // Owner hariç tüm token sahiplerine reflection dağıt
        address[] memory holders = _getTokenHolders(); // Bu fonksiyonu implement etmemiz gerekecek
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] != owner()) { // Owner'ı hariç tut
                uint256 holderBalance = balanceOf(holders[i]);
                uint256 reflectionAmount = (holderBalance * reflectionPerToken) / 10**18;
                if (reflectionAmount > 0) {
                    _mint(holders[i], reflectionAmount);
                }
            }
        }
        
        totalReflected += amount;
        emit ReflectionDistributed(amount);
    }
    
    function mint() external {
        require(isEligibleForMint(msg.sender), "Not eligible for minting");
        
        uint256 mintAmount = getCurrentMintAmount();
        uint256 reflectionRate = getCurrentReflectionRate();
        uint256 reflectionAmount = (mintAmount * reflectionRate) / 100;
        
        hasMinted[msg.sender] = true;
        lastMintBlock[msg.sender] = block.number;
        totalMintedWallets++;
        
        // Önce kullanıcıya tokenları mint et
        _mint(msg.sender, mintAmount);
        
        // Sonra reflection dağıtımını yap
        if (reflectionAmount > 0) {
            _distributeReflection(reflectionAmount);
        }
        
        emit TokensMinted(msg.sender, mintAmount, reflectionAmount);
    }
} 
