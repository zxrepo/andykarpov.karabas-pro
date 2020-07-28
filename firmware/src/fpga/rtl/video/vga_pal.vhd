--------------------------------------------------------------------------------
--  ПРОШИВКА ПЛИС ДЛЯ УСТРОЙСТВА: "ZXKit1 - ПЛАТА VGA & PAL"                  --                        
--  ВЕРСИЯ:  V2.0.8.08                                          ДАТА: 091223  --
--  АВТОР:   САБИРЖАНОВ ВАДИМ                                                 --
--
--  Modified by Andy Karpov
--  2020-07-20: Added profi video mode support and forced switch via DS80
--  2020-07-20: Replaced ext video ram with 2-port fpga sram
--------------------------------------------------------------------------------

-- Compilation Report:
-- Warnings        = 55
-- Total macrocels = 123/128
-- Total pins      = 72/80

library IEEE;
library altera; 
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use altera.altera_primitives_components.all;

entity VGA_PAL is
	port
	(

--------------------------------------------------------------------------------
--                 ВХОДНЫЕ СИГНАЛЫ ПЛИС СО СПЕКТРУМА                  091103  --
--------------------------------------------------------------------------------

RGB_IN 		: in std_logic_vector(8 downto 0); -- RRRGGGBBB
DS80			: in std_logic := '0';
KSI_IN      : in std_logic := '1'; -- кадровые синхроимпульсы
SSI_IN      : in std_logic := '1'; -- строчные синхроимпульсы
CLK         : in std_logic := '1'; -- тактовые импульсы частотой 14 / 12 МГц
CLK2       	: in std_logic := '1'; -- удвоенная CLK

--------------------------------------------------------------------------------
--             ПЕРЕМЫЧКИ / ТУМБЛЕРЫ ДЛЯ УПРАВЛЕНИЯ РЕЖИМАМИ           090812  --
--------------------------------------------------------------------------------

INVERSE_KSI   : in std_logic := '1'; -- инверсия кадровых синхроимпульсов: 
                                     -- 0 - инвертировать, 1 - нет.
                                      
INVERSE_SSI   : in std_logic := '1'; -- инверсия строчных синхроимпульсов: 
                                     -- 0 - инвертировать, 1 - нет.
                                      
INVERSE_F	  : in std_logic := '1'; -- инверсия тактовых импульсов: 
                                     -- 0 - инвертировать, 1 - нет.
                                      
--------------------------------------------------------------------------------
--                     ВЫХОДНЫЕ ПОРТЫ ПЛИС ДЛЯ VGA                    090728  --
--------------------------------------------------------------------------------

RGB_O 	  : out std_logic_vector(8 downto 0) := (others => '0'); -- выход VGA RGB
VSYNC_VGA  : out std_logic := '1'; -- кадровые синхроимпульсы/синхроимп. SCART
HSYNC_VGA  : out std_logic := '1' -- строчные синхроимпульсы/enable RGB SCART

);
    end VGA_PAL;
architecture RTL of VGA_PAL is

--------------------------------------------------------------------------------
--                       ВНУТРЕННИЕ СИГНАЛЫ ПЛИС                      090804  --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   НОРМАЛИЗОВАННЫЕ ВХОДНЫЕ СИГНАЛЫ                  090805  --
--------------------------------------------------------------------------------

signal RGB 	  : std_logic_vector(8 downto 0);
signal RGBI_CLK : std_logic; -- тактовый сигнал входного кода цвета

signal KSI    : std_logic; -- кадровые синхроимпульсы
signal SSI    : std_logic; -- строчные синхроимпульсы

--------------------------------------------------------------------------------
--                     СИГНАЛЫ ДЛЯ СБРОСА СЧЕТЧИКОВ                   091220  --
--------------------------------------------------------------------------------

signal KSI_1  : std_logic; -- выборка кадрового синхроимпульса
signal KSI_2  : std_logic; -- задержанные кадровые синхроимпульсы
signal SSI_2  : std_logic; -- задержанные строчные синхроимпульсы

--------------------------------------------------------------------------------
--              СЧЕТЧИКИ И ПАРАМЕТРЫ РАЗВЕРТКИ ДЛЯ VGA И VIDEO        091223  --
--------------------------------------------------------------------------------
-- строчная развертка VGA:

signal VGA_H_CLK     : std_logic; -- сигнал увеличения счетчика тактов в строке
signal VGA_H         : std_logic_vector(8 downto 0); -- счетчик тактов в строке
signal VGA_H_MIN     : std_logic_vector(8 downto 0); -- мин. знач.счетч. тактов
signal VGA_H_MAX     : std_logic_vector(8 downto 0); -- макс.знач.счетч. тактов
signal VGA_SSI1_BGN   : std_logic_vector(9 downto 0); -- начало строчного СИ
signal VGA_SSI1_END   : std_logic_vector(9 downto 0); -- конец  строчного СИ
signal VGA_SSI2_BGN   : std_logic_vector(9 downto 0); -- начало строчного СИ
signal VGA_SSI2_END   : std_logic_vector(9 downto 0); -- конец  строчного СИ
signal VGA_SGI1_BGN   : std_logic_vector(9 downto 0); -- начало строчного ГИ
signal VGA_SGI1_END   : std_logic_vector(9 downto 0); -- конец  строчного ГИ
signal VGA_SGI2_BGN   : std_logic_vector(9 downto 0); -- начало строчного ГИ
signal VGA_SGI2_END   : std_logic_vector(9 downto 0); -- конец  строчного ГИ
--------------------------------------------------------------------------------
-- кадровая развертка VGA:

signal VGA_V_CLK     : std_logic; -- сигнал увеличения счетчика строк в кадре
signal VGA_V         : std_logic_vector(9 downto 0); -- счетчик строк в кадре
signal VGA_V_MIN     : std_logic_vector(9 downto 0); -- мин. знач.счетчика строк
signal VGA_V_MAX     : std_logic_vector(9 downto 0); -- макс.знач.счетчика строк
signal VGA_KSI_BGN   : std_logic_vector(9 downto 0); -- начало кадрового СИ
signal VGA_KSI_END   : std_logic_vector(9 downto 0); -- конец  кадрового СИ
signal VGA_KGI1_END  : std_logic_vector(9 downto 0); -- конец  кадрового ГИ
signal VGA_KGI2_BGN  : std_logic_vector(9 downto 0); -- начало кадрового ГИ
--------------------------------------------------------------------------------
-- строчная развертка VIDEO:

signal VIDEO_H_CLK   : std_logic; -- сигнал увеличения счетчика тактов в строке
signal VIDEO_H       : std_logic_vector(9 downto 0); -- счетчик тактов в строке
signal VIDEO_H_MAX   : std_logic_vector(9 downto 0); -- макс.знач. счетч. тактов
signal VIDEO_SSI_BGN : std_logic_vector(9 downto 0); -- начало строчного СИ
signal VIDEO_SSI_END : std_logic_vector(9 downto 0); -- конец  строчного СИ
signal VIDEO_SGI_BGN : std_logic_vector(9 downto 0); -- начало строчного ГИ
signal VIDEO_SGI_END : std_logic_vector(9 downto 0); -- конец  строчного ГИ
--------------------------------------------------------------------------------
-- кадровая развертка VIDEO:

signal VIDEO_V_CLK   : std_logic;  --сигнал увеличения счетчика строк в кадре
signal VIDEO_V       : std_logic_vector(8 downto 0); -- счетчик строк в кадре
signal VIDEO_V_MAX   : std_logic_vector(8 downto 0); -- макс.знач. счетч. тактов
signal VIDEO_KSI_BGN : std_logic_vector(8 downto 0); -- начало кадрового СИ
signal VIDEO_KSI_END : std_logic_vector(8 downto 0); -- конец  кадрового СИ
signal VIDEO_KGI_BGN : std_logic_vector(8 downto 0); -- начало кадрового ГИ
signal VIDEO_KGI_END : std_logic_vector(8 downto 0); -- конец  кадрового ГИ
signal SCREEN_V_END  : std_logic_vector(8 downto 0); -- конец акт. части экрана
--------------------------------------------------------------------------------
-- тип компьютера/параметры развертки в строке: 

signal H_TYPE : std_logic_vector(1 downto 0); 
                
                --  10 - стандартная или удвоенная частота точек
                --       графики клонов "Спектрум", кварц на 14 МГц
                --       в строке 896 тактов (895 = 1 10 1111111)
                
                --  01 - режим графики "Профи", кварц на 12 МГц
                --       в строке 768 тактов (767 = 1 01 1111111)

                --  00 - режим графики "Орион", кварц на 10 МГц
                --       в строке 640 тактов (639 = 1 00 1111111)

                --  11 - режим графики "Специалист", кварц на 8 МГц
                --       в строке 512 тактов (511 = 0 11 1111111)
--------------------------------------------------------------------------------
signal V_TYPE : std_logic; -- тип экрана по-вертикали / число строк в кадре: 
                --   0 - 312 строк (311 = 10011 0 111)
                --   1 - 320 строк (319 = 10011 1 111)

--------------------------------------------------------------------------------
--                     СИНХРОИМПУЛЬСЫ ДЛЯ VGA И VIDEO                 091220  --
--------------------------------------------------------------------------------

signal VGA_KSI      : std_logic; -- кадровые синхроимпульсы для VGA
signal VGA_SSI      : std_logic; -- строчные синхроимпульсы для VGA

signal VIDEO_KSI    : std_logic; -- кадровые синхроимпульсы для VIDEO
signal VIDEO_SSI1   : std_logic; -- основные строчные синхроимпульсы для VIDEO
signal VIDEO_SSI2   : std_logic; -- строчные синхроимпульсы - врезки для VIDEO
signal VIDEO_SYNC   : std_logic; -- синхросмесь для VIDEO

signal VGA_RBGI_CLK : std_logic; -- синхроимпульсы для вывода на VGA 

signal RESET_ZONE   : std_logic; -- сигнал для синхроницации счетчика тактов
signal RESET_H      : std_logic; -- если 0, то можно сбрасывать счетчик тактов    
signal RESET_V      : std_logic; -- если 0, то можно сбрасывать счетчик строк    
 
--------------------------------------------------------------------------------
--                    ГАСЯЩИЕ ИМПУЛЬСЫ ДЛЯ VGA И VIDEO                091102  --
--------------------------------------------------------------------------------

signal VGA_KGI      : std_logic; -- кадровые гасящие импульсы для VGA
signal VGA_SGI      : std_logic; -- строчные гасящие импульсы для VGA
signal VGA_BLANK    : std_logic; -- гасящие импульсы для VGA

signal VIDEO_KGI    : std_logic; -- кадровые гасящие импульсы для VIDEO
signal VIDEO_SGI    : std_logic; -- строчные гасящие импульсы для VIDEO
signal VIDEO_BLANK  : std_logic; -- гасящие импульсы для VIDEO

--------------------------------------------------------------------------------
--                РЕГИСТР ДЛЯ ЧТЕНИЯ ТОЧКИ В ОЗУ            			 090821  --
--------------------------------------------------------------------------------

signal RD_REG       : std_logic_vector(8 downto 0);

begin

--------------------------------------------------------------------------------
--                            ПРОЦЕССЫ                                        --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   НОРМАЛИЗАЦИЯ ВХОДНЫХ СИГНАЛОВ                    090826  --
--------------------------------------------------------------------------------

-- если соответствующая перемычка/тумблер находится в положении ON, 
-- что соответствует логическому нулю, соответствующий сигнал инвертируется.
-- затем код цвета тактируются
--------------------------------------------------------------------------------
RGBI_CLK <= CLK2 xnor INVERSE_F; -- нормализация тактовых синхроимпульсов
--------------------------------------------------------------------------------
process (RGBI_CLK)   
begin
  if (falling_edge(RGBI_CLK)) then -- если спад тактового импульса
--------------------------------------------------------------------------------
        RGB <= RGB_IN;
  end if;
end process;

--RGB <= RGB_IN;

--------------------------------------------------------------------------------
--              ФОРМИРОВАНИЕ СИГНАЛОВ ДЛЯ СБРОСА СЧЕТЧИКОВ            091223  --
--------------------------------------------------------------------------------
process (CLK, VIDEO_H(8),VIDEO_H(9))
begin

  if (rising_edge(CLK)) then  -- если фронт тактового импульса, переход из 0 в 1
      SSI   <= SSI_IN xnor INVERSE_SSI;
      SSI_2 <= not SSI;       -- задержка на такт строчного синхроимпульса
  end if;
end process;

process (KSI, KSI_2, VGA_H(8), VIDEO_H(9))
begin
  -- выборка состояния кадрового синхроимпульса во время 1/4...1/2 строки VIDEO
  if (rising_edge(VIDEO_H(8)) and VIDEO_H(9)='0') then
      KSI   <= KSI_IN xnor INVERSE_KSI;
      KSI_2 <= not KSI;       -- задержка кадрового синхроимпульса на строку 
  end if;
end process;

RESET_H <= SSI or SSI_2;      -- если 0, то можно сбрасывать счетчик тактов    
RESET_V <= KSI or KSI_2;      -- если 0, то можно сбрасывать счетчик строк
-- зона для сброса счетчиков, 0 в средней части экрана по-вертикали
RESET_ZONE  <= (not VIDEO_V(7) or VIDEO_V(8)); 

VGA_V_CLK   <= (VGA_H(7)   or VGA_H(8));
VIDEO_V_CLK <= (VIDEO_H(8) or VIDEO_H(9));

--------------------------------------------------------------------------------
--              ЗАПОМИНАНИЕ КОЛИЧЕСТВА ТАКТОВ В СТРОКЕ                091220  --
--------------------------------------------------------------------------------

process (SSI)
begin
  if (falling_edge(SSI)) then -- если спад  строчного синхроимпульса,
    if RESET_ZONE = '0'  then -- если зона для сброса счетчиков
      -- упрощенно запоминаем состояние счетчика тактов в строке
                --  10 - стандартная или удвоенная частота точек
                --       графики клонов "Спектрум", кварц на 14 МГц
                --       в строке 896 тактов (895 = 1 10 1111111)
                
                --  01 - режим графики "Профи", кварц на 12 МГц
                --       в строке 768 тактов (767 = 1 01 1111111)

                --  00 - режим графики "Орион", кварц на 10 МГц
                --       в строке 640 тактов (639 = 1 00 1111111)

                --  11 - режим графики "Специалист", кварц на 8 МГц
                --       в строке 512 тактов (511 = 0 11 1111111)
      --H_TYPE <= VIDEO_H(8 downto 7);
    end if;
  end if;
end process;

-- переключение видео-режимов по внешнему сигналу 
H_TYPE <= "01" when DS80 = '1' else "10";

--------------------------------------------------------------------------------
--              ЗАПОМИНАНИЕ КОЛИЧЕСТВА СТРОК В КАДРЕ                  091016  --
--------------------------------------------------------------------------------
process (KSI)
begin
  if (falling_edge(KSI)) then -- если спад  строчного синхроимпульса,
    V_TYPE <= VIDEO_V(3); -- упрощенно запоминает состояние счетчика строк VIDEO
                          -- 0 = 312 строк, 1 = 320 строк
  end if;
end process;


--------------------------------------------------------------------------------
--                 УПРАВЛЕНИЕ СЧЕТЧИКАМИ ТАКТОВ В СТРОКАХ             091220  --
--------------------------------------------------------------------------------
process (CLK)
begin  
  -- максимальное значение счетчика точек VGA 
  VGA_H_MAX <= ( H_TYPE(1) nand H_TYPE(0) ) & H_TYPE(1 downto 0) & "111111";

  if (falling_edge(CLK)) then          -- иначе, по спаду тактового импульса:

    -- если начало строчного СИ и строка в средней части экрана по-вертикали:
    -- синхронизируем счетчики тактов с входными синхроимпульсами
    if (RESET_H or RESET_ZONE) = '0'  then
      VGA_H     <= (others => '0');    -- обнуляем счетчик тактов VGA
      VIDEO_H   <= (others => '0');    -- обнуляем счетчик тактов VIDEO
      
    else                               -- иначе - автономный счет:
   
      if (VGA_H = VGA_H_MAX) then      -- если последний такт в строке VGA,
        VGA_H   <= (others => '0');    -- обнуляем счетчик тактов VGA
      else
        VGA_H   <= VGA_H + 1;          -- иначе - увеличиваем счетчик тактов
      end if;    

      if (VIDEO_H = (VGA_H_MAX & "1")) then -- если послед. такт в строке VIDEO,
        VIDEO_H <= (others => '0');    -- обнуляем счетчик тактов VGA
      else
        VIDEO_H <= VIDEO_H + 1;        -- иначе - увеличиваем счетчик тактов
      end if;    

   end if;   
  end if;   
end process;

--------------------------------------------------------------------------------
--                 УПРАВЛЕНИЕ СЧЕТЧИКАМИ СТРОК В КАДРЕ                091223  --
--------------------------------------------------------------------------------
-- чтобы не было смещения экрана вниз при частоте VGA 60 Гц 
-- пропускаются 29.5 строк экрана Спектрума сверху экрана, 
-- что соответствует 59 строкам VGA.


process (VGA_H(8), VIDEO_H(9))
begin
--------------------------------------------------------------------------------
-- счетчик строк VGA:
  if (falling_edge(VGA_V_CLK)) then  -- по спаду сигнала увеличения счетч. строк

    -- выходная частота кадров 48/50 Гц
      if (RESET_V) = '0' then        -- если начало кадрового синхроимпульса:
        VGA_V <= (others => '0');    -- обнуляем счетчик строк VGA
      else                           -- иначе 
        VGA_V <= VGA_V   + 1;        -- увеличиваем счетчик строк VGA
      end if;    
  end if;    
--------------------------------------------------------------------------------
-- счетчик строк VIDEO:
  if (falling_edge(VIDEO_V_CLK)) then -- по спаду сигнала увеличения счетч.строк
    if (RESET_V) = '0' then           -- если начало кадрового синхроимпульса:
      VIDEO_V <= (others => '0');     -- обнуляем счетчик строк VIDEO
    else    
      VIDEO_V <= VIDEO_V + 1;         -- увеличиваем счетчик строк VIDEO
    end if;    
  end if;    
-------------------------------------------------------------------------------
end process;

--------------------------------------------------------------------------------
--                ФОРМИРОВАНИЕ ПАРАМЕТРОВ РАЗВЕРТКИ VGA               091223  --
--------------------------------------------------------------------------------
-- строчные синхроимпульсы для VGA:

process (H_TYPE)                   
begin
  case H_TYPE is
 
    when "10" =>   -- "Спектрум"
      -- строчная развертка VGA:
      VGA_SSI1_BGN <= "0000000000"; --   0 - начало 1 строчного СИ
      VGA_SSI1_END <= "0000100110"; --  38 - конец  1 строчного СИ
      VGA_SSI2_BGN <= "1101110010"; -- 882 - начало 2 строчного СИ
      VGA_SSI2_END <= "1101111111"; -- 895 - конец  2 строчного СИ
      VGA_SGI1_END <= "0001000001"; --  65 - конец  1 строчного ГИ
      VGA_SGI2_BGN <= "1101110010"; -- 882 - начало 2 строчного ГИ

    when "01" =>   -- "Профи"
      VGA_SSI1_BGN <= "0000000000"; --   0 - начало 1 строчного СИ
      VGA_SSI1_END <= "0000100010"; --  34 - конец  1 строчного СИ
      VGA_SSI2_BGN <= "1011110101"; -- 757 - начало 2 строчного СИ
      VGA_SSI2_END <= "1011111111"; -- 767 - конец  2 строчного СИ
      VGA_SGI1_END <= "0000111001"; --  57 - конец  1 строчного ГИ
      VGA_SGI2_BGN <= "1011101101"; -- 749 - начало 2 строчного ГИ

    when "00" =>   -- "Орион"
      VGA_SSI1_BGN <= "0000000000"; --   0 - начало 1 строчного СИ
      VGA_SSI1_END <= "0000100101"; --  37 - конец  1 строчного СИ
      VGA_SSI2_BGN <= "0000000000"; --   0 - начало 2 строчного СИ
      VGA_SSI2_END <= "0000100101"; --  37 - конец  2 строчного СИ
      VGA_SGI1_END <= "0000111000"; --  56 - конец  1 строчного ГИ
      VGA_SGI2_BGN <= "1001111010"; -- 634 - начало 2 строчного ГИ

    when "11" =>   -- "Специалист"
      VGA_SSI1_BGN <= "0000000000"; --   0 - начало 1 строчного СИ
      VGA_SSI1_END <= "0000010001"; --  17 - конец  1 строчного СИ
      VGA_SSI2_BGN <= "0111110011"; -- 499 - начало 2 строчного СИ
      VGA_SSI2_END <= "0111111111"; -- 511 - конец  2 строчного СИ
      VGA_SGI1_END <= "0000100000"; --  32 - конец  1 строчного ГИ
      VGA_SGI2_BGN <= "0111101110"; -- 494 - начало 2 строчного ГИ

  end case;
end process;
--------------------------------------------------------------------------------
-- кадровая развертка VGA:

-- чтобы не было смещения экрана вниз при частоте VGA 60 Гц 
-- пропускаются 32 строки экрана Спектрума сверху экрана, 
-- что соответствует 64 строкам VGA.

VGA_KSI_BGN  <= "0000001011"; --  11 - начало кадрового СИ
VGA_KSI_END  <= "0000001100"; --  12 - конец  кадрового СИ
VGA_KGI1_END <= "0000101100"; --  44 - конец  кадрового ГИ
VGA_KGI2_BGN <= "1001110001"; -- 625 - начало кадрового ГИ

--------------------------------------------------------------------------------
--                   ФОРМИРОВАНИЕ СТРОЧНЫХ ИМПУЛЬСОВ VGA              091223  --
--------------------------------------------------------------------------------
-- основные строчные синхроимпульсы для VIDEO
VGA_SSI  <= '0' when (VGA_H >= VGA_SSI1_BGN and VGA_H <= VGA_SSI1_END) 
                  or (VGA_H >= VGA_SSI2_BGN and VGA_H <= VGA_SSI2_END) 
                else '1';

-- строчные гасящие импульсы для VIDEO
VGA_SGI  <= '0' when (VGA_H <= VGA_SGI1_END)
                  or (VGA_H >= VGA_SGI2_BGN)
                else '1';

--------------------------------------------------------------------------------
--                   ФОРМИРОВАНИЕ КАДРОВЫХ ИМПУЛЬСОВ VGA              091223  --
--------------------------------------------------------------------------------
-- кадровые синхроимпульсы для VIDEO
VGA_KSI  <= '0' when (VGA_V >= VGA_KSI_BGN) 
                 and (VGA_V <= VGA_KSI_END) 
                else '1';
-- кадровые гасящие импульсы для VIDEO
VGA_KGI  <= '0' when (VGA_V <= VGA_KGI1_END) 
                  or (VGA_V >= VGA_KGI2_BGN )  
                else '1';
                  
--------------------------------------------------------------------------------
--                    ФОРМИРОВАНИЕ СТРОЧНЫХ ИМПУЛЬСОВ VIDEO           091223  --
--------------------------------------------------------------------------------

-- основные строчные синхроимпульсы для VIDEO:

                       -- клон Спектрума (14 МГц)
VIDEO_SSI1 <= '0' when (VIDEO_H > 20 and VIDEO_H < 87 and H_TYPE = "10")
                       -- Профи (12 МГц)
                    or (VIDEO_H > 17 and VIDEO_H < 75 and H_TYPE = "01")
                       -- Орион (10 МГц)
                    or (VIDEO_H > 14 and VIDEO_H < 62 and H_TYPE = "00")
                
                  else '1';

-- строчные синхроимпульсы - врезки для VIDEO:
                       -- клон Спектрума (14 МГц)
VIDEO_SSI2 <= '0' when (VIDEO_H > 20 and VIDEO_H < 851 and H_TYPE = "10")
                       -- Профи (12 МГц)
                    or (VIDEO_H > 17 and VIDEO_H < 729 and H_TYPE = "01")
                       -- Орион (10 МГц)
                    or (VIDEO_H > 14 and VIDEO_H < 608 and H_TYPE = "00")
                
                  else '1';

-- строчные гасящие импульсы для VIDEO:
                       -- клон Спектрума (14 МГц)
VIDEO_SGI  <= '0' when (VIDEO_H < 168 and H_TYPE = "10")
                       -- Профи (12 МГц)
                    or (VIDEO_H < 144 and H_TYPE = "01")
                       -- Орион (10 МГц)
                    or (VIDEO_H < 120 and H_TYPE = "00")
                
                  else '1';

--------------------------------------------------------------------------------
--                   ФОРМИРОВАНИЕ КАДРОВЫХ ИМПУЛЬСОВ VIDEO            091103  --
--------------------------------------------------------------------------------
-- кадровые синхроимпульсы для VIDEO
VIDEO_KSI  <= '0' when VIDEO_V < 4 else '1';

-- кадровые гасящие импульсы для VIDEO
VIDEO_KGI  <= '0' when VIDEO_V < 16 else '1';


--------------------------------------------------------------------------------
--                    ФОРМИРОВАНИЕ СИНХРОСМЕСИ ДЛЯ VIDEO              090820  --
--------------------------------------------------------------------------------
VIDEO_SYNC <= VIDEO_SSI2 when VIDEO_KSI = '0' else VIDEO_SSI1;

--------------------------------------------------------------------------------
--                    ФОРМИРОВАНИЕ СМЕСИ ГАСЯЩИХ ИМПУЛЬСОВ            091025  --
--------------------------------------------------------------------------------
-- гасящие импульсы для VGA
--VGA_BLANK   <= VGA_KGI and VGA_SGI;

-- гасящие импульсы для VIDEO
VIDEO_BLANK <= VIDEO_KGI and VIDEO_SGI;

--------------------------------------------------------------------------------
--                     VIDEO ОЗУ                										--
--------------------------------------------------------------------------------

LINEBUF: entity work.linebuf
port map (
	address_a => VIDEO_V(0) & VIDEO_H(9 downto 0),
	clock_a 	 => CLK2,
	data_a 	 => RGB,
	wren_a 	 => '1',
	q_a 		 => open,
	
	address_b => (not VIDEO_V(0)) & VGA_H(8 downto 0) & CLK,
	clock_b 	 => VGA_RBGI_CLK,
	data_b 	 => (others => '1'),
	wren_b 	 => '0',
	q_b 		 => RD_REG
);

--------------------------------------------------------------------------------
-- синхронизация гасящих импульсов и вывод синхроимпульсов

process (CLK) 
begin
if (rising_edge(CLK)) then  -- если фронт тактового импульса, переход из 0 в 1
      -- гасящие импульсы для VGA
      VGA_BLANK   <= VGA_KGI and VGA_SGI;

      VSYNC_VGA <= VGA_KSI;      -- кадровые синхроимпульсы для VGA
      HSYNC_VGA <= VGA_SSI;      -- строчные синхроимпульсы для VGA
  end if;
end process;

-- удвоение частоты с помощью задержанного сигнала
VGA_RBGI_CLK <= CLK2; 
      
--------------------------------------------------------------------------------
--                      вывод RGBI на разъем VGA                      091024  --
--------------------------------------------------------------------------------
process (VGA_RBGI_CLK) 
begin
  if (rising_edge(VGA_RBGI_CLK)) then  -- если фронт тактового импульса,
	 if (VGA_BLANK = '0') then 
		RGB_O <= (others => '0');
	 else 
		RGB_O <= RD_REG;
	 end if;
  end if;
end process;

end RTL;

