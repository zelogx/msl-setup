# Zelogx™ Multiverse Secure Lab Setup End User License Agreement (EULA)

Last Updated: 2026-01-25

This End User License Agreement (hereinafter, the “EULA”) sets forth the terms and conditions
for the use of “Zelogx™ Multiverse Secure Lab Setup (Personal Edition)” and
“Zelogx™ Multiverse Secure Lab Setup Pro Corporate Edition”
(collectively, the “Product”) and the related documentation provided by Zelogx Project
(hereinafter, the “Project”).

By clicking a button such as “Agree and Download” on the download page of the Product,
or by downloading, installing, copying, or using the Product,
whichever occurs first, the user (the “User”) shall be deemed to have agreed to all provisions of this EULA.

---

## 1. Definitions

Unless otherwise expressly provided, the terms used in this EULA shall have the meanings set forth in each of the following items:

1. **“Software”**  
   “Software” means the executable program components and the set of automation processes within the “Zelogx™ Multiverse Secure Lab Setup” family provided by the Licensor, and includes, as parts thereof, the following items:

   - A full set of automated deployment scripts (including shell scripts and other automation modules)  
   - Configuration templates and sample configuration files  
   - Executable binaries, libraries, and compiled code  
   - Auxiliary scripts and tools necessary for the operation of the Software

2. **“Documentation”**  
   “Documentation” means all documents, diagrams, tutorials, manuals, and design materials provided by the Licensor in connection with the installation, configuration, operation, and architecture of the Software,  
   regardless of whether such materials are provided in electronic form, printed materials, or any other medium.

3. **“Licensor”**  
   “Licensor” means **Zelogx Project**, which owns the copyrights and all other intellectual property rights in and to the Product and grants licenses under this EULA.  
   Any reference in this EULA to the “license provider” shall have the same meaning as the Licensor.

4. **“Licensee”**  
   “Licensee” means any individual, corporation, or other entity that has lawfully obtained a license or right to use the Product, whether for consideration or free of charge, and has been granted the authority to use the Product under this EULA (collectively, “User” or “Users”).  
   Where the User is a corporation or other entity, its officers, employees, contractors, and other persons who use the Product under the control of such entity shall be deemed to be included in the User.

5. **“Product”**  
   “Product” means the aggregate of the **Software** and **Documentation** defined above,  
   and includes any items provided to the User by means of license keys, download links, or any other delivery method.  
   This EULA applies to both “Zelogx™ Multiverse Secure Lab Setup (Personal Edition)” and
   “Zelogx™ Multiverse Secure Lab Setup Pro Corporate Edition.”

6. **“Personal Licensee”**  
   “Personal Licensee” means a natural person who is the registered license holder and has obtained the right to use “Zelogx™ Multiverse Secure Lab Setup (Personal Edition).”  
   A Personal Licensee may use the Product in environments owned or controlled by such person (such as a home lab),  
   including, by way of example, personal learning and testing environments and home lab environments operated by freelancers,  
   in each case separated from any corporate organization.  
   The specific scope of permitted use by a Personal Licensee shall be governed by this EULA and any additional usage conditions separately presented by the Project.

7. **“Corporate Licensee”**  
   “Corporate Licensee” means a company, organization, association, or other similar business entity that is the registered license holder and has obtained the right to use “Zelogx™ Multiverse Secure Lab Setup Pro Corporate Edition.”  
   Where officers, employees, contractors, or similar persons of a Corporate Licensee use the Product in the course of their duties, such use shall be deemed use by the Corporate Licensee.  
   The specific conditions of use, including the number of permitted hosts and projects granted to a Corporate Licensee, shall be set forth in separate agreements, quotations, or license certificates.

8. **“Licensed Host”**  
   “Licensed Host” means, primarily in relation to “Zelogx™ Multiverse Secure Lab Setup Pro Corporate Edition,”  
   a Proxmox VE host or other server environment on which the Product is installed or on which the Product executes automated configuration,  
   and includes any virtual machines, containers, and virtual networks built on such environment.  
   Where a maximum number of Licensed Hosts is specified for a paid edition, the Corporate Licensee may use the Product only within such upper limit.

9. **“Authorized User”**  
   “Authorized User” means an individual who is under the control of the User and is permitted to use the Product for the User’s business or other purposes.  
   Authorized Users shall be bound by this EULA and shall be subject to the same obligations as the User.


---

## 2. Grant of License and Licensed Hosts

1. In accordance with this EULA and any additional usage conditions separately presented by the Project,
   the Licensor grants the User a non-exclusive, non-transferable right to use the Product
   within the scope set forth in this EULA.  
   The usage conditions of the Product shall differ depending on whether the User is a Personal Licensee
   or a Corporate Licensee, as provided in the following paragraphs.

2. **Grant of License to Personal Licensees (Personal Edition)**  
   Unless otherwise expressly specified, a Personal Licensee may install and use the Product
   on Proxmox VE hosts and other server environments (including home lab environments)
   that are owned or operated under the Personal Licensee’s own responsibility and discretion.  
   A Personal Licensee may use the Product within the following scope:

   - Use for personal learning, testing, and research  
   - Use by a freelancer or other individual business owner as an internal development, testing,
     or lab environment for their own business  
   - Use of environments built with the Product as a tool, and provision to clients or other third parties
     of deliverables created in such environments
     (including, for example, design documents, source code, and test results)

   However, a Personal Licensee may not engage in any of the following:

   - Installing the Product on Proxmox VE hosts owned or controlled by a client or other third party,
     and providing such environment to that party, whether for consideration or free of charge  
   - Reselling or re-providing, as a service or product, the environment itself that consists of
     the Product or is primarily based on the Product  

   Where any of the above types of use are carried out, the relevant client or business entity
   must obtain a license for “MSL Setup Pro Corporate Edition”
   as a “Corporate Licensee.”

3. **Host-Based License for Corporate Licensees (Pro Corporate Edition)**  
   Licenses for “Zelogx™ Multiverse Secure Lab Setup Pro Corporate Edition” obtained by a Corporate Licensee
   are, in principle, granted on a per-host basis.  
   The maximum number of hosts on which the Corporate Licensee may use the Product
   (the “Licensed Host Count”) shall be the upper limit expressly stated in the purchased license type,
   quotation, purchase order, license certificate, or other transaction documents.

4. A Corporate Licensee shall not install the Product, or execute automated configuration by the Product,
   in excess of the Licensed Host Count.  
   If the Corporate Licensee wishes to use the Product on additional hosts, it shall obtain additional licenses.

5. If a Personal Licensee installs or configures the Product on a Proxmox VE host
   that is owned or managed by a corporation or other entity,
   such corporation or entity shall, notwithstanding the preceding paragraphs,
   be deemed a Corporate Licensee and must obtain a license for
   MSL Setup Pro Corporate Edition.

6. If, for the purposes of incident response, hardware maintenance, or disaster recovery,
   the Product is temporarily migrated to another host,  
   the User (particularly a Corporate Licensee) may use any already downloaded copy of the Product
   to install and use the Product on the replacement host,
   provided that this is done within the Licensed Host Count.  
   In such case, after recovery is complete, the User shall uninstall the Product from any host
   on which it is no longer required, or take other appropriate steps,
   so that the number of hosts on which the Product is used at the same time
   does not exceed the Licensed Host Count.  
   (For Personal Licensees, the upper limit on the number of hosts shall be governed by this EULA
   and any additional usage conditions separately presented by the Project,
   and the specific restriction on the Licensed Host Count in this paragraph
   does not directly apply.)

7. If it becomes necessary to reinstall the Product for the purpose described in the preceding paragraph,
   and the User no longer retains the installer or previously downloaded files of the Product,
   the User may contact the Licensor by e-mail at info@zelogx.com
   or by any other method designated by the Licensor,  
   and receive from the Licensor a re-download link or instructions on how to obtain the Product.  
   The Licensor may require identity verification or other reasonable confirmation procedures,
   and the method and conditions of such re-provisioning may be changed by the Licensor at any time.

8. The User may create copies of the Product (including backup copies)
   to the extent reasonably necessary for installing and operating the Product in the User’s environment.  
   However, such copies may be used only for the purpose of reinstallation and configuration management
   of the Product by the User, and may not be used for distribution, transfer, or loan to any third party.

9. The User may, at the User’s own responsibility, modify configuration files, scripts,
   and other components of the Product to adapt them to the User’s own environment,
   or use the Product in combination with other tools.  
   However, regardless of whether modifications have been made,
   the User may not redistribute the Product or any part thereof to any third party,
   nor may the User distribute to any third party software that incorporates the Product,
   as provided in Article 3 (Prohibited Acts).

10. The usage rights granted under this EULA may be exercised for both commercial and non-commercial purposes,
    within the scope set forth in paragraph 2 for Personal Licensees
    and in paragraph 3 and any separate agreements for Corporate Licensees.  
    However, in any case, the User may not resell the Product itself or any software or service
    that is primarily based on the Product as a competing product,  
    nor may the User provide a product that is substantially equivalent in functionality to the Product,
    as provided in Article 3 (Prohibited Acts).

---

## 3. Prohibited Acts

The User shall not engage in any of the following acts in connection with the use of the Product:

1. Unless expressly permitted under this EULA or the applicable purchase or usage conditions,
   redistributing, distributing, selling, lending, or granting a sublicense for the Product
   (whether or not modified) or any copies thereof to any third party.

2. Providing to any third party any software, script, template, or other deliverable
   that incorporates the Product or any part thereof,
   as a product or service that has functions or purposes that are substantially equivalent
   to those of the Product.

3. Hosting or providing the Product itself, or its principal functions, in such a manner that
   it can be directly operated or used as the Product by any third party other than the User.  
   This includes providing the installation, execution, project creation, or other functions
   of the Product as a hosting service, SaaS, managed service, or other similar offering
   that is made available to third parties.  
   However, it is permitted, within the scope of Article 2, for the User to provide applications
   or services to third parties on virtual machines, containers, or networks
   built using the Product.

4. In the case of Corporate Licensees, installing the Product or executing automated configuration
   by the Product on any host in excess of the Licensed Host Count specified in Article 2, paragraph 3.  
   In addition, regardless of whether the User is a Personal Licensee or Corporate Licensee,
   installing or allowing the use of the Product, without a valid license under this EULA,
   on any host owned or controlled by a third party who is not the User.

5. Disclosing, sharing, or causing to be leaked to any third party
   any license key, activation code, download link, or other authentication information
   required to obtain or use the Product.

6. Circumventing, disabling, modifying, or otherwise undermining
   any technical protection measures, access controls, license management functions,
   or similar mechanisms applicable to the Product,
   or engaging in any act that has a similar effect.

7. Reverse engineering, decompiling, disassembling,
   or otherwise analyzing the source code of the Product.  
   Notwithstanding the foregoing, this shall not apply to the extent and under the conditions
   that such acts are expressly permitted to the User
   under the copyright laws or other applicable laws of Japan
   or any other relevant jurisdiction.

8. Removing, obscuring, or altering any copyright notices, trademarks, logos,
   or other proprietary notices affixed to the Product or the Documentation.

9. Using all or any part of the Product or the Documentation in a manner that infringes
   the rights of the Licensor or any third party,
   or in a manner that violates the laws or regulations of Japan
   or of the country or region in which the User is located.

10. Publishing or displaying, in connection with the Product, the Documentation, or this EULA,
    any false information in a manner that damages, or is likely to damage,
    the credit or reputation of the Licensor or the Product.

11. Causing any third party to engage in any of the acts set forth in the preceding items,
    or encouraging or facilitating any such acts by a third party.

12. Any other act that is clearly contrary to the purpose of this EULA
    and unreasonably prejudices the legitimate interests of the Licensor.

13. Assigning, causing to be succeeded, or granting as security
    all or any part of the contractual status under this EULA,
    or any rights or obligations of the User under this EULA,
    to any third party without the prior written consent of the Licensor.

14. Exporting, re-exporting, or providing outside Japan to any third party
    the Product or any related technical information
    in a manner that violates the Foreign Exchange and Foreign Trade Act of Japan
    or any other applicable export control laws and regulations of Japan, the United States,
    or any other relevant jurisdiction.


---

## 4. Intellectual Property Rights and Public Communications

1. All copyrights and any other intellectual property rights in and to the Software, the Documentation,
   and any documents, images, or other outputs automatically generated by the Software
   (collectively, the “Generated Works”) shall belong to the Licensor or the rightful owner thereof.  
   Except where expressly licensed under this EULA, no rights in or to the Product
   shall be transferred or assigned to the User.

2. During the term of this EULA, the Licensor grants the User a non-exclusive right
   to view, store, modify, and use the Generated Works for internal materials and similar purposes,
   to the extent necessary for the User’s business or other legitimate purposes.  
   However, the User may not provide the Generated Works, in whole or in substantially the same form
   (including where edited or adapted), to any third party as a product or service
   that is of the same type as, or competes with, the Product.

3. Any intellectual property rights in existing system designs, design documents, scripts, data,
   or other deliverables created by the User prior to the use of the Product
   or independently of the Product shall remain vested in the User or the respective rightful owner,
   and shall not be transferred to the Licensor by virtue of this EULA.

4. The User may publish its own usage experiences, evaluations, and technical insights relating to the Product
   in the form of blog posts, reviews, presentation materials, internal or external technical documents,
   or other similar formats.  
   In doing so, the User is, in principle, expected to use its own wording and screenshots or similar materials
   captured by the User. However, this does not preclude the User from quoting,
   within the legally permitted scope of quotation, excerpts of explanatory text
   from the official Zelogx website, README files, or similar materials.  
   Notwithstanding the foregoing, the User shall not reproduce and repost
   the source code, scripts, configuration files, or original text of the Documentation
   contained in the Product in a manner that reproduces the whole, or a substantial part,
   of such documents.

5. The User is always permitted, and encouraged, to place links to the official Zelogx website,
   official repositories, and other official information relating to the Product.  
   However, the User shall make any such public communications at the User’s own responsibility, and,
   even if any dispute arises with a third party as a result of such communications,
   the Licensor shall bear no responsibility whatsoever,
   except in cases where the Licensor has acted with intent or gross negligence.


## 5. Disclaimer of Warranties and Limitation of Liability

1. **Form of Provision and Scope of Warranty**  
   Although the Product is developed and tested by the Licensor with reasonable care,
   it is provided on an “AS IS” basis.  
   The Licensor does not undertake any obligation to warrant, with respect to the Product,  
   its accuracy, completeness, usefulness, fitness for a particular purpose,
   the achievement of any expected functions, performance, or results,
   the absence of security vulnerabilities, the absence of defects or errors,
   or that any such defects or errors will necessarily be corrected  
   (except to the extent that exclusion or limitation of such warranties is not permitted by applicable law).  
   If the Licensor and the User have entered into a separate maintenance agreement or other individual agreement
   that specifies support details or service levels, the provisions of such individual agreement
   shall prevail over this paragraph.

2. **No Warranty as to Availability or Defects**  
   The Licensor does not warrant that the Product will be available at all times without interruption,
   that the Product or any updates or fixes provided by the Licensor
   will be suitable for the User’s specific environment or purposes,
   or that any defects or malfunctions of the Product will necessarily be corrected.

3. **Exclusion of Liability for Indirect and Other Damages**  
   Except in cases of willful misconduct or gross negligence on the part of the Licensor,
   the Licensor shall not be liable to the User, regardless of foreseeability,
   for any damages arising out of or in connection with the use or inability to use the Product.  
   Such damages include, but are not limited to, the following:

   - Loss of business opportunities, sales, or profits  
   - Loss, destruction, alteration, leakage, or corruption of data  
   - Damages resulting from system downtime, delay, or malfunction  
   - Indirect, incidental, special, or consequential damages

4. **Limitation of Aggregate Liability**  
   Notwithstanding the preceding paragraph, if, under applicable law,
   the Licensor is held liable to the User for any damages in connection with the use of the Product,
   the total aggregate amount of damages for which the Licensor is responsible
   shall not exceed the total amount of consideration actually paid by the User to the Licensor
   during the twelve (12) months immediately preceding the event giving rise to such liability
   in relation to the use of the Product  
   (in the case of a one-time payment, the purchase price of the license;  
   where no consideration was paid, the maximum shall be zero (0)).

5. **Disputes with Third Parties**  
   Even if any dispute arises between the User and a third party
   as a result of deliverables, public communications, configuration settings,
   or any other acts of use created or performed by the User using the Product or the Documentation,
   the Licensor shall bear no responsibility whatsoever,
   except in cases of willful misconduct or gross negligence on the part of the Licensor.  
   Notwithstanding the foregoing, the Licensor may, at its sole discretion,
   provide support in accordance with Article 4, paragraph 5.

6. **Relationship with Mandatory Laws**  
   The foregoing provisions shall apply to the maximum extent permitted by
   the Consumer Contract Act of Japan and any other mandatory provisions of applicable law.
   To the extent that the exclusion or limitation of the Licensor’s liability is not permitted,
   this EULA shall be effective only within the scope that does not violate such laws.  
   In such case, the Licensor’s liability shall be limited to the minimum extent permitted
   under the applicable laws.

---

## 6. Changes to this EULA

1. The Licensor may, in accordance with Article 548-4 of the Japanese Civil Code,
   amend the contents of this EULA without obtaining the individual consent of the User
   if any of the following conditions are met:

   1. The amendment of this EULA is in the general interest of the Users; or  
   2. The amendment of this EULA does not conflict with the purpose of the contract,
      and, in light of the necessity of the amendment, the reasonableness of the amended provisions,
      the existence of a provision in this EULA indicating that its terms may be amended as standard terms,
      and other circumstances relating to such amendment,
      the amendment is reasonable.

2. When amending this EULA, the Licensor shall notify Users of
   the amended contents of this EULA and the effective date thereof
   by posting such information on the Licensor’s official website or official distribution pages
   (including, without limitation, GitHub repositories),
   or by any other method that the Licensor deems appropriate,
   within a reasonable period of time prior to the effective date.

3. The amended EULA shall apply to all Users who use the Product
   on or after the effective date specified in the preceding paragraph.
   If a User continues to use the Product on or after such effective date,
   the User shall be deemed to have agreed to the amended EULA.

---

## 7. Governing Law and Jurisdiction

1. The formation, validity, performance, and interpretation of this EULA
   shall be governed by the laws of Japan.

2. If any dispute arises between the User and the Licensor
   in connection with this EULA or the Product,
   the Tokyo District Court shall have exclusive jurisdiction
   as the court of first instance.  
   This agreement on jurisdiction shall remain valid and in force
   even if the User is located outside Japan.

3. If there is any inconsistency or discrepancy between the Japanese version of this EULA
   and any translated version, the Japanese version shall prevail.

---

## 8. Term and Termination

1. This EULA shall become effective at the earlier of the time when the User
   begins downloading, installing, copying, or using the Product,
   and shall remain in force for as long as the User continues to use the Product
   under this EULA.

2. The User may terminate its use of the Product under this EULA at any time
   by ceasing all use of the Product and uninstalling or deleting the Product
   and all copies thereof from any hosts or other environments
   on which the Product has been installed.  
   In such case, any license fees or other consideration already paid
   shall not be refunded.

3. If the Licensor determines that the User falls under any of the following items,
   the Licensor may, without prior notice or demand,
   immediately suspend the User’s use of the Product under this EULA
   or terminate this EULA:

   1. The User commits a material breach of this EULA
      (including, without limitation, a breach of the prohibited acts set forth in Article 3).  
   2. The User fails to fulfill its payment obligations
      with respect to license fees or any other amounts relating to the Product.  
   3. The User becomes subject to attachment, provisional attachment, provisional disposition,
      disposition for arrears of taxes, or any other compulsory execution.  
   4. A petition is filed for bankruptcy, civil rehabilitation, corporate reorganization,
      special liquidation, or any other similar proceeding in respect of the User.  
   5. The User transfers all or a material part of its business to a third party,
      or is dissolved.  
   6. Any other reasonable cause arises under which the Licensor determines
      that it is clearly inappropriate for the User to continue using the Product.

4. If this EULA is terminated pursuant to the preceding paragraph,
   the User shall immediately cease all use of the Product and
   delete or destroy all copies of the Product and any copies thereof
   stored on any hosts or other media.  
   Upon request from the Licensor, the User shall provide the Licensor
   with a written certification to that effect.

5. Even after the termination or expiration of this EULA,
   Article 1 (Definitions), Article 2, paragraphs 8 through 10
   (provisions concerning permitted use within a certain scope),
   Article 3 (Prohibited Acts), Article 4 (Intellectual Property Rights and Public Communications),
   Article 5 (Disclaimer of Warranty and Limitation of Liability),
   Article 6 (Amendment of this EULA), Article 7 (Governing Law and Jurisdiction),
   paragraph 4 and this paragraph of this Article 8,
   and any other provisions which by their nature are intended to survive
   the termination or expiration of this EULA
   shall remain in full force and effect.

---

## 9. Miscellaneous

1. **Non-Waiver of Rights**  
   Even if the Licensor or the User does not exercise all or any part of the rights
   granted under this EULA, such non-exercise shall not be construed
   as a waiver of those rights.  
   Furthermore, any waiver of rights once made shall not be construed
   as a continuing waiver for the future,
   unless there is an express written agreement to that effect.

2. **Invalidity or Partial Invalidity of Provisions**  
   Even if all or any part of any provision of this EULA is held invalid or unenforceable
   under applicable laws or regulations, the remaining provisions shall continue
   to remain in full force and effect.  
   Any portion that has been held invalid or unenforceable shall, to the maximum extent possible,
   be interpreted so as to be valid and enforceable and to reflect the original intent.

3. **Entire Agreement**  
   This EULA constitutes the entire agreement between the Licensor and the User
   with respect to the Product, and supersedes all prior or contemporaneous
   oral or written agreements, proposals, and understandings relating to the Product.  
   However, if the Licensor and the User have entered into an individual agreement
   that contains provisions different from this EULA
   (including, without limitation, maintenance agreements or enterprise agreements),
   the provisions of such individual agreement shall prevail over this EULA.

4. **Headings**  
   The article titles, headings, and section labels used in this EULA
   are for convenience only and shall not affect the interpretation of this EULA.

5. **Measures in Case of Breach**  
   If the User breaches this EULA, in addition to the measures provided for
   in the preceding Article and other provisions of this EULA,
   the Licensor may, to the extent necessary and reasonable, take the following measures:

   1. Invalidation of the Product’s license keys or download links  
   2. Suspension of the provision of the Product from repositories,
      distribution sites, or other locations managed by the Licensor  
   3. Requesting corrective measures corresponding to the content of the breach
      and holding discussions regarding measures to prevent recurrence  
   4. Considering and exercising legal measures as necessary,
      including claims for damages and requests for injunctive relief


## 10. (Contact Information)  
   Any inquiries regarding this EULA or the Product shall be directed to the following
   email address:  
   info@zelogx.com
